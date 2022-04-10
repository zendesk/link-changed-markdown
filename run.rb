#!/usr/bin/env ruby
# frozen_string_literal: true

# No specific ruby version; only core dependencies
# (Using Javascript would fit better with the Github platform:
# https://docs.github.com/en/actions/creating-actions/creating-a-javascript-action)

require 'json'
require_relative './comment_builder'
require_relative './comment_writer'
require_relative './github_client'

github_client = GithubClient.new
event = JSON.parse(File.read(ENV.fetch('GITHUB_EVENT_PATH')))

builder = CommentBuilder.new(event, github_client)
writer = CommentWriter.new(event, github_client)

comment_text = builder.build
writer.write(comment_text)
