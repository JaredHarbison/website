module Admin
  class IssuesController < BaseController
    STATUSES = %w[new reviewed resolved].freeze

    def index
      @status = params[:status].presence
      @category = params[:category].presence
      @activity_class = params[:activity_class].presence
      scoped = EngagementEvent.where(event_type: "issue_reported")
      scoped = if @activity_class == "internal_qa"
        scoped.from_internal_qa
      else
        scoped.from_live_recruiter
      end
      scoped = scoped.includes(:opportunity).order(occurred_at: :desc)
      scoped = scoped.select { |event| @status.blank? || (event.metadata["issue_status"].presence || "new") == @status }
      scoped = scoped.select { |event| @category.blank? || event.metadata["issue_category"] == @category }
      @issue_count = scoped.length
      @total_pages = [ 1, (@issue_count / 20.0).ceil ].max
      @page = [ params.fetch(:page, 1).to_i, 1 ].max
      @issues = paginate(scoped)
      @categories = scoped.map { |event| event.metadata["issue_category"] }.compact.uniq.sort
    end

    def show
      @issue = EngagementEvent.where(event_type: "issue_reported").find(params[:id])
      @opportunity = @issue.opportunity
    rescue ActiveRecord::RecordNotFound
      admin_not_found
    end

    def update
      issue = EngagementEvent.where(event_type: "issue_reported").find(params[:id])
      status = params.dig(:engagement_event, :issue_status).to_s
      raise ActionController::BadRequest, "Invalid issue status" unless STATUSES.include?(status)

      issue.update!(metadata: issue.metadata.merge("issue_status" => status))
      redirect_to admin_issue_path(issue), notice: "Issue status updated."
    rescue ActiveRecord::RecordNotFound
      admin_not_found
    end

    private

    def paginate(records)
      records.slice((@page - 1) * 20, 20) || []
    end
  end
end
