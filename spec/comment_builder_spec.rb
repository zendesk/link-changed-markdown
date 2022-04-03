# frozen_string_literal: true

require 'json'
require_relative '../comment_builder'

RSpec.describe CommentBuilder do
  let(:real_event) { JSON.parse(File.read(File.join(File.dirname(__FILE__), 'pull-1-opened-event.json'))) }
  let(:real_files) { JSON.parse(File.read(File.join(File.dirname(__FILE__), 'pull-1-files.json'))) }
  let(:real_url) { 'https://api.github.com/repos/zendesk/link-changed-markdown/pulls/1' }

  let(:github_client) { double('github-client') }

  def run(pr_url, event, files, expected_text)
    allow(github_client).to receive(:get).with("#{pr_url}/files?per_page=100").and_return(files)
    builder = CommentBuilder.new(event, github_client)
    text = builder.build
    expect(text).to eq(expected_text)
  end

  it 'works for the real data' do
    run(real_url, real_event, real_files, <<~TEXT)
      <!-- link-changed-markdown -->

      Markdown changes in this PR:

      * modified: [README.md](https://github.com/zendesk/link-changed-markdown/blob/zdrve/md-test/README.md) ([view this on the base branch](https://github.com/zendesk/link-changed-markdown/blob/main/README.md))
      * added: [new.md](https://github.com/zendesk/link-changed-markdown/blob/zdrve/md-test/new.md)
    TEXT
  end

  it 'only considers markdown' do
    files = [
      { 'filename' => 'foo.txt', 'status' => 'added' },
      { 'filename' => 'foo.md', 'status' => 'added' }
    ]
    run(real_url, real_event, files, <<~TEXT)
      <!-- link-changed-markdown -->

      Markdown changes in this PR:

      * added: [foo.md](https://github.com/zendesk/link-changed-markdown/blob/zdrve/md-test/foo.md)
    TEXT
  end

  it 'sorts by filename' do
    files = [
      { 'filename' => 'foo.md', 'status' => 'added' },
      { 'filename' => 'bar/x.md', 'status' => 'added' },
      { 'filename' => 'bar.md', 'status' => 'added' },
      { 'filename' => 'Bar.md', 'status' => 'added' }
    ]
    run(real_url, real_event, files, <<~TEXT)
      <!-- link-changed-markdown -->

      Markdown changes in this PR:

      * added: [Bar.md](https://github.com/zendesk/link-changed-markdown/blob/zdrve/md-test/Bar.md)
      * added: [bar.md](https://github.com/zendesk/link-changed-markdown/blob/zdrve/md-test/bar.md)
      * added: [bar/x.md](https://github.com/zendesk/link-changed-markdown/blob/zdrve/md-test/bar/x.md)
      * added: [foo.md](https://github.com/zendesk/link-changed-markdown/blob/zdrve/md-test/foo.md)
    TEXT
  end

  it 'handles added' do
    files = [
      { 'filename' => 'file1.md', 'status' => 'added' }
    ]
    run(real_url, real_event, files, <<~TEXT)
      <!-- link-changed-markdown -->

      Markdown changes in this PR:

      * added: [file1.md](https://github.com/zendesk/link-changed-markdown/blob/zdrve/md-test/file1.md)
    TEXT
  end

  it 'handles modified' do
    files = [
      { 'filename' => 'file2.md', 'status' => 'modified' }
    ]
    run(real_url, real_event, files, <<~TEXT)
      <!-- link-changed-markdown -->

      Markdown changes in this PR:

      * modified: [file2.md](https://github.com/zendesk/link-changed-markdown/blob/zdrve/md-test/file2.md) ([view this on the base branch](https://github.com/zendesk/link-changed-markdown/blob/main/file2.md))
    TEXT
  end

  it 'handles removed' do
    files = [
      { 'filename' => 'file3.md', 'status' => 'removed' }
    ]
    run(real_url, real_event, files, <<~TEXT)
      <!-- link-changed-markdown -->

      Markdown changes in this PR:

      * removed: file3.md ([view this on the base branch](https://github.com/zendesk/link-changed-markdown/blob/main/file3.md))
    TEXT
  end

  it 'ignores renamed' do
    files = [
      { 'filename' => 'file4.md', 'status' => 'renamed' }
    ]
    run(real_url, real_event, files, nil)
  end

  # Can handle 0 changes - tested by the "renamed" scenario
  # Can handle 1 change - tested by most of the scenarios

  it 'can handle 10 changes' do
    files = 10.times.map do |i|
      { 'filename' => "file#{i}.md", 'status' => 'added' }
    end

    outputs = 10.times.map do |i|
      "* added: [file#{i}.md](https://github.com/zendesk/link-changed-markdown/blob/zdrve/md-test/file#{i}.md)"
    end

    run(real_url, real_event, files, <<~TEXT)
      <!-- link-changed-markdown -->

      Markdown changes in this PR:

      #{outputs.join("\n")}
    TEXT
  end

  it 'can handle 11 changes' do
    files = (10..20).map do |i|
      { 'filename' => "file#{i}.md", 'status' => 'added' }
    end

    outputs = (10..19).map do |i|
      "* added: [file#{i}.md](https://github.com/zendesk/link-changed-markdown/blob/zdrve/md-test/file#{i}.md)"
    end

    run(real_url, real_event, files, <<~TEXT)
      <!-- link-changed-markdown -->

      Markdown changes in this PR:

      #{outputs.join("\n")}
      * and 1 more
    TEXT
  end
end
