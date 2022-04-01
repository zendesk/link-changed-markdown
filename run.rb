#!/usr/bin/env ruby

# No specific ruby version; only core dependencies
# (Using Javascript would fit better with the Github platform:
# https://docs.github.com/en/actions/creating-actions/creating-a-javascript-action)

require 'net/http'
require 'json'

MAGIC_TEXT = '<!-- link-changed-markdown -->'
MAX_LISTED = 10

def github_api_session
  @session ||= begin
    http = Net::HTTP.new('api.github.com', 443)
    http.use_ssl = true
    http.start
    http
  end
end

def user_and_password(file)
  @user_and_password ||= begin
    creds = JSON.parse(File.read(file))
    "#{creds.fetch('github').fetch('user')}:#{creds.fetch('github').fetch('pass')}"
  end
end

def do_request(klass, url, expected_status, body = nil)
  uri = URI.parse(url)
  req = klass.new(uri)

  if file = ENV['DEBUG_CREDENTIALS_PATH']
    req['Authorization'] = "Basic #{[user_and_password(file)].pack('m0')}"
  else
    req['Authorization'] = "Bearer #{ENV.fetch('GITHUB_TOKEN')}"
  end

  req['Accept'] = 'application/vnd.github.v3+json'

  if body
    req.body = JSON.generate(body)
    req['Content-Type'] = 'application/json'
  end

  res = github_api_session.request(req)
  if res.code == expected_status.to_s
    return(res.body && JSON.parse(res.body))
  end

  raise <<~MESSAGE
    #{req.method} #{url} -> HTTP/#{res.http_version} #{res.code} #{res.message} (expected #{expected_status})
  MESSAGE
end

def get(url)
  do_request(Net::HTTP::Get, url, 200)
end

def post(url, body)
  do_request(Net::HTTP::Post, url, 201, body)
end

def patch(url, body)
  do_request(Net::HTTP::Patch, url, 200, body)
end

def delete(url)
  do_request(Net::HTTP::Delete, url, 204)
end

def event
  @event ||= begin
    JSON.parse(File.read(ENV.fetch('GITHUB_EVENT_PATH')))
  end
end

def find_changed_files
  # TODO: pagination
  changes = get(event.fetch("pull_request").fetch("url") + "/files?per_page=100")

  markdown_changes = changes.select { |c| c.fetch("filename").end_with?(".md") }

  # return array of [filename, exists_on_base, exists_on_head]
  markdown_changes.map do |c|
    status = c.fetch("status")
    [c.fetch("filename"), (status != "added"), (status != "removed")]
  end
end

def build_comment(changed_markdown_files)
  return nil if changed_markdown_files.empty?

  text = <<~COMMENT
    #{MAGIC_TEXT}

    Markdown changes in this PR:

  COMMENT

  # This can be broken by unexpected characters in branch names or filenames
  base = event.fetch("pull_request").fetch("base")
  head = event.fetch("pull_request").fetch("head")
  base_url = "#{base.fetch("repo").fetch("html_url")}/blob/#{base.fetch("ref")}"
  head_url = "#{head.fetch("repo").fetch("html_url")}/blob/#{head.fetch("ref")}"

  sorted_changes = changed_markdown_files.sort_by(&:first)

  sorted_changes.take(MAX_LISTED).each do |(filename, exists_on_base, exists_on_head)|
    line = if exists_on_head && !exists_on_base
      # create
      "* added: [#{filename}](#{head_url}/#{filename})"
    elsif exists_on_head
      # update
      "* updated: [#{filename}](#{head_url}/#{filename}) ([view this on the base branch](#{base_url}/#{filename}))"
    else
      # delete
      "* removed: #{filename} ([view this on the base branch](#{base_url}/#{filename}))"
    end

    text += "#{line}\n"
  end

  if sorted_changes.count > MAX_LISTED
    more = sorted_changes.count - MAX_LISTED
    text += "* and #{more} more\n"
  end

  text
end

def find_existing_comment
  url = event.fetch("pull_request").fetch("comments_url")

  # TODO: pagination
  url += "?per_page=100"

  comments = get(url)
  comments.find { |c| c.fetch("body").include?(MAGIC_TEXT) }
end

def update_pr(comment_text, existing_comment)
  if !comment_text.nil? && existing_comment.nil?
    url = event.fetch("pull_request").fetch("comments_url")
    post(url, { body: comment_text })
  elsif !comment_text.nil?
    patch(existing_comment.fetch("url"), { body: comment_text })
  elsif existing_comment
    delete(existing_comment.fetch("url"))
  end
end

changed_markdown_files = find_changed_files
comment_text = build_comment(changed_markdown_files)
existing_comment = find_existing_comment
update_pr(comment_text, existing_comment)
