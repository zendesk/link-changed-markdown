# frozen_string_literal: true

# No specific ruby version; only core dependencies
# (Using Javascript would fit better with the Github platform:
# https://docs.github.com/en/actions/creating-actions/creating-a-javascript-action)

class CommentBuilder
  MAGIC_TEXT = '<!-- link-changed-markdown -->'
  MAX_LISTED = 10

  def initialize(event, github_client)
    @event = event
    @github_client = github_client
  end

  attr_reader :event, :github_client

  def build
    build_comment(find_changed_files)
  end

  private

  def find_changed_files
    # TODO: pagination
    changes = github_client.get("#{event.fetch('pull_request').fetch('url')}/files?per_page=100")

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
end
