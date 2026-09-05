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

    def new
    end

    def access_links
      @query = params[:q].to_s.strip
      @access_links = Opportunity.includes(:ask_token).where.not(ask_tokens: { id: nil }).order(created_at: :desc)
      if @query.present?
        pattern = "%#{Opportunity.sanitize_sql_like(@query)}%"
        @access_links = @access_links.where("opportunities.company LIKE :pattern OR opportunities.role_title LIKE :pattern OR opportunities.purpose LIKE :pattern OR opportunities.external_id LIKE :pattern", pattern: pattern)
      end
      @access_count = @access_links.count
      @page = [ params.fetch(:page, 1).to_i, 1 ].max
      @total_pages = [ 1, (@access_count / 20.0).ceil ].max
      @access_links = @access_links.limit(20).offset((@page - 1) * 20)
    end

    def show
      opportunity = Opportunity.find(params[:id])
      @summary = AskJared::EngagementExport.new(scope: Opportunity.where(id: opportunity.id), include_internal: true).call.first
      @events = opportunity.engagement_events
        .where(event_type: EngagementEvent::EVENT_TYPES)
        .order(occurred_at: :asc)
      @sessions = @events.reject { |event| event.event_type == "token_resolved" }.group_by(&:session_digest).values.sort_by { |events| events.first.occurred_at }
      admin_not_found unless @summary
    rescue ActiveRecord::RecordNotFound
      admin_not_found
    end
  end
end
