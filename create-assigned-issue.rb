#!/usr/bin/env ruby
banner = <<-BANNER
Usage: create-assigned-issue.rb <issue URL>
  * Copies issue as template
  * Replaces any references to the assigned user (eg, at-mentions, etc.)
  * Also "undoes" any checkboxes in issue template (eg, [x] -> [ ])
  * For each collaborator of repo, creates a new issue, assigned to collaborator
BANNER

$stderr.sync = true
require 'octokit'
require 'optparse'

file      = __FILE__
issue_url = ARGV.first
token     = ENV['TOKEN']

abort banner unless issue_url || issue_url == '-h'

REGEX = %r{github\.com/([^/]+/[^/]+)/issues/(\d+)}
# https://github.com/username/reponame/issues/2
# -> username/reponame, 2
def parse_issue_url(url)
  if md = REGEX.match(url)
    [md[1], md[2]]
  end
end

Octokit.auto_paginate = true

client       = Octokit::Client.new :access_token => ENV['TOKEN']
repo, number = parse_issue_url(issue_url)
issue        = client.issue(repo, number)
assigned     = issue.assignee.login
template     = issue.body.gsub("[x] ", "[ ] ")
template     = template.gsub("#{assigned}", "%{assignee}")
title        = issue.title
title        = title.gsub("#{assigned}", "%{assignee}")

client.collaborators(repo).each do |collaborator|
  next if assigned == collaborator[:login]
  title    = title % { assignee: collaborator[:login] }
  body     = template % { assignee: collaborator[:login] }
  assignee = collaborator[:login]

  puts "Creating assigned issue for @#{collaborator[:login]}"
  client.create_issue repo, title, body, assignee: assignee
end
