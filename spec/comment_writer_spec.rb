# frozen_string_literal: true

require 'json'
require_relative '../comment_writer'

RSpec.describe CommentWriter do
  let(:real_event) { JSON.parse(File.read(File.join(File.dirname(__FILE__), 'pull-1-opened-event.json'))) }
  let(:real_comments) { JSON.parse(File.read(File.join(File.dirname(__FILE__), 'pull-1-comments.json'))) }
  let(:real_url) { 'https://api.github.com/repos/zendesk/link-changed-markdown/issues/1' }

  let(:github_client) { double('github-client') }

  it 'can create a comment' do
    real_comments.first['body'] = 'just a normal comment'
    allow(github_client).to receive(:get)
      .with("#{real_url}/comments?per_page=100")
      .and_return(real_comments)
    expect(github_client).to receive(:post)
      .with("#{real_url}/comments", { body: 'new comment' })
      .and_return({ 'url' => 'a-url' })
    writer = CommentWriter.new(real_event, github_client)
    writer.write('new comment')
  end

  it 'can update a comment' do
    allow(github_client).to receive(:get)
      .with("#{real_url}/comments?per_page=100")
      .and_return(real_comments)
    expect(github_client).to receive(:patch)
      .with(real_comments.first['url'], { body: 'new comment' })
      .and_return({ 'url' => 'a-url' })
    writer = CommentWriter.new(real_event, github_client)
    writer.write('new comment')
  end

  it "can leave a comment alone if it's already correct" do
    allow(github_client).to receive(:get)
      .with("#{real_url}/comments?per_page=100")
      .and_return(real_comments)
    writer = CommentWriter.new(real_event, github_client)
    writer.write(real_comments.first['body'])
  end

  it 'can remove the existing comment' do
    allow(github_client).to receive(:get)
      .with("#{real_url}/comments?per_page=100")
      .and_return(real_comments)
    expect(github_client).to receive(:delete)
      .with(real_comments.first['url'])
    writer = CommentWriter.new(real_event, github_client)
    writer.write(nil)
  end

  it 'can decline to add a comment, if none is needed' do
    real_comments.first['body'] = 'just a normal comment'
    allow(github_client).to receive(:get)
      .with("#{real_url}/comments?per_page=100")
      .and_return(real_comments)
    writer = CommentWriter.new(real_event, github_client)
    writer.write(nil)
  end
end
