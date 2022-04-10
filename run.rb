#!/usr/bin/env ruby
# frozen_string_literal: true

# No specific ruby version; only core dependencies
# (Using Javascript would fit better with the Github platform:
# https://docs.github.com/en/actions/creating-actions/creating-a-javascript-action)

require 'net/http'
require 'json'

MAGIC_TEXT = '<!-- link-changed-markdown -->'
MAX_LISTED = 10

def github_api_session
  @github_api_session ||= begin
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

  req['Authorization'] = if (file = ENV['DEBUG_CREDENTIALS_PATH'])
                           "Basic #{[user_and_password(file)].pack('m0')}"
                         else
                           "Bearer #{ENV.fetch('GITHUB_TOKEN')}"
                         end

  req['Accept'] = 'application/vnd.github.v3+json'

  if body
    req.body = JSON.generate(body)
    req['Content-Type'] = 'application/json'
  end

  res = github_api_session.request(req)
  return(res.body && JSON.parse(res.body)) if res.code == expected_status.to_s

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
  @event ||= JSON.parse(File.read(ENV.fetch('GITHUB_EVENT_PATH')))
end

def find_changed_files
  # TODO: pagination
  changes = get("#{event.fetch('pull_request').fetch('url')}/files?per_page=100")

  changes.select { |c| c.fetch('filename').end_with?('.md') && c.fetch('status') != 'renamed' }
         .sort_by { |c| c.fetch('filename') }
end

def build_comment(changed_markdown_files)
  puts "Building comment about #{changed_markdown_files.count} changed files"
  return nil if changed_markdown_files.empty?

  text = <<~COMMENT
    #{MAGIC_TEXT}

    Markdown changes in this PR:

  COMMENT

  # This can be broken by unexpected characters in branch names or filenames
  base = event.fetch('pull_request').fetch('base')
  head = event.fetch('pull_request').fetch('head')
  base_url = "#{base.fetch('repo').fetch('html_url')}/blob/#{base.fetch('ref')}"
  head_url = "#{head.fetch('repo').fetch('html_url')}/blob/#{head.fetch('ref')}"

  sorted_changes = changed_markdown_files

  sorted_changes.take(MAX_LISTED).each do |change|
    filename = change.fetch('filename')
    status = change.fetch('status')

    head_link = "[#{filename}](#{head_url}/#{filename})"
    base_link = "[view this on the base branch](#{base_url}/#{filename})"

    line = case status
           when 'added'
             "* added: #{head_link}"
           when 'modified'
             "* modified: #{head_link} (#{base_link})"
           when 'removed'
             "* removed: #{filename} (#{base_link})"
           else
             "* ? #{status.inspect}"
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
  url = event.fetch('pull_request').fetch('comments_url')

  # TODO: pagination
  url += '?per_page=100'

  comments = get(url)
  comment = comments.find { |c| c.fetch('body').include?(MAGIC_TEXT) }

  if comment
    puts "Found existing comment #{comment.fetch('url')}"
  else
    puts 'No existing comment'
  end

  comment
end

def update_pr(comment_text, existing_comment)
  if !comment_text.nil? && existing_comment.nil?
    url = event.fetch('pull_request').fetch('comments_url')
    c = post(url, { body: comment_text })
    puts "Created comment #{c.fetch('url')}"
  elsif !comment_text.nil?
    if existing_comment.fetch('body') == comment_text
      puts 'Comment is already correct'
    else
      c = patch(existing_comment.fetch('url'), { body: comment_text })
      puts "Updated comment #{c.fetch('url')}"
    end
  elsif existing_comment
    delete(existing_comment.fetch('url'))
    puts "Deleted comment #{existing_comment.fetch('url')}"
  end
end

changed_markdown_files = find_changed_files
comment_text = build_comment(changed_markdown_files)
existing_comment = find_existing_comment
update_pr(comment_text, existing_comment)
