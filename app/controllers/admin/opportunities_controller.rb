module Admin
  class OpportunitiesController < BaseController
    def index
      include_internal = params[:activity_class] == "internal_qa"
      all = AskJared::EngagementExport.new(include_internal: include_internal).call
      @filter = params[:filter].presence
      all = all.select do |summary|
        case @filter
        when "engaged" then summary[:meaningful_session_count].positive?
        when "asked" then summary[:meaningful_question_count].positive?
        when "sharing" then summary[:possible_internal_share]
        when "issues" then summary[:issue_report_count].positive?
        when "no_activity" then summary[:meaningful_session_count].zero?
        else true
        end
      end
      all.sort_by! { |summary| [ summary[:meaningful_session_count].positive? || summary[:meaningful_question_count].positive? ? 0 : 1, -(summary[:last_meaningful_engagement_at]&.to_i || 0) ] }
      @page = [ params.fetch(:page, 1).to_i, 1 ].max
      @opportunity_count = all.length
      @total_pages = [ 1, (@opportunity_count / 20.0).ceil ].max
      @opportunities = all.slice((@page - 1) * 20, 20) || []
    end

    def show
      opportunity = Opportunity.find(params[:id])
      @summary = AskJared::EngagementExport.new(scope: Opportunity.where(id: opportunity.id)).call.first
      @events = opportunity.engagement_events
        .where(event_type: AskJared::EngagementExport::EVENT_TYPES)
        .order(occurred_at: :asc)
      admin_not_found unless @summary
    rescue ActiveRecord::RecordNotFound
      admin_not_found
    end
  end
end
