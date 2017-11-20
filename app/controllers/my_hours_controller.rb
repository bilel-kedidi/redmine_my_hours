class MyHoursController < ApplicationController
  unloadable
  before_filter :find_project

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :journals
  helper :issues
  helper :projects
  helper :custom_fields
  helper :issue_relations
  helper :watchers
  helper :attachments
  helper :queries
  include QueriesHelper
  helper :repositories
  helper :sort
  include SortHelper
  helper :timelog


  default_search_scope :issues

  accept_rss_auth :index, :show
  accept_api_auth :index, :show, :create, :update, :destroy

  def index
    params.merge!({"set_filter" => "1", "sort"=>"id:desc", "f"=>["status_id", ""],
                   "op"=>{"status_id"=>"c"}, "c"=>["status", "subject", "spent_hours"],
                   "group_by"=>"closed_on_date", "t"=>["spent_hours", ""]})

    retrieve_query
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      case params[:format]
        when 'csv', 'pdf'
          @limit = Setting.issues_export_limit.to_i
          if params[:columns] == 'all'
            @query.column_names = @query.available_inline_columns.map(&:name)
          end
        when 'atom'
          @limit = Setting.feeds_limit.to_i
        when 'xml', 'json'
          @offset, @limit = api_offset_and_limit
          @query.column_names = %w(author)
        else
          @limit = per_page_option
      end

      @issue_count = @query.issue_count
      @issue_pages = Paginator.new @issue_count, @limit, params['page']
      @offset ||= @issue_pages.offset
      @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
                              :order => sort_clause,
                              :offset => @offset,
                              :limit => @limit)
      @issue_count_by_group = @query.issue_count_by_group

      respond_to do |format|
        format.html { }
        format.api  {
          Issue.load_visible_relations(@issues) if include_in_api_response?('relations')
        }
        format.atom { render_feed(@issues, :title => "#{@project || Setting.app_title}: #{l(:label_issue_plural)}") }
        format.csv  { send_data(query_to_csv(@issues, @query, params[:csv]), :type => 'text/csv; header=present', :filename => 'issues.csv') }
        format.pdf  { send_file_headers! :type => 'application/pdf', :filename => 'closed_issues.pdf' }
      end
    else
      respond_to do |format|
        format.html {  }
        format.any(:atom, :csv, :pdf) { render(:nothing => true) }
        format.api { render_validation_errors(@query) }
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  private

  def find_project
    @project = Project.find params[:project_id]
  rescue
    render_404
  end

end