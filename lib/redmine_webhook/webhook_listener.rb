module RedmineWebhook
  class WebhookListener < Redmine::Hook::Listener

    def controller_issues_new_after_save(context = {})
      issue = context[:issue]
      controller = context[:controller]
      project = issue.project
      webhooks = Webhook.where(:project_id => project.project.id)
      return unless webhooks
      post(webhooks, issue_to_json(issue, controller))
    end

    def controller_issues_edit_after_save(context = {})
      journal = context[:journal]
      controller = context[:controller]
      issue = context[:issue]
      project = issue.project
      webhooks = Webhook.where(:project_id => project.project.id)
      return unless webhooks
      post(webhooks, journal_to_json(issue, journal, controller))
    end

    private
    def issue_to_json(issue, controller)
      {
        :payload => {
          :action => 'opened',
          :issue => RedmineWebhook::IssueWrapper.new(issue).to_hash,
          :url => controller.issue_url(issue)
        }
      }.to_json
    end

    def journal_to_json(issue, journal, controller)
      {
        :payload => {
          :action => 'updated',
          :issue => RedmineWebhook::IssueWrapper.new(issue).to_hash,
          :journal => RedmineWebhook::JournalWrapper.new(journal).to_hash,
          :url => controller.issue_url(issue)
        }
      }.to_json
    end

    $LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '.'))
    require 'jandi_api_wrapper'    
    include Jandi_api_wrapper

    def post(webhooks, request_body)
      Thread.start do
        webhooks.each do |webhook|
          begin
            if !webhook.url.match(/wh.jandi.com/).nil?
              send_to_jandi(webhook.url,JSON.parse(request_body))
            Faraday.post do |req|
              req.url webhook.url
              req.headers['Content-Type'] = 'application/json'
              req.body = request_body
             end
            end
          Rails.logger.error JSON.parse(request_body)
          rescue => e
            Rails.logger.error e
          end
        end
      end
    end
  end
end
