Redmine::Plugin.register :redmine_my_hours do
  name 'Redmine My Hours plugin'
  author 'Bilel kedidi'
  description 'This is a plugin for Redmine'
  version '0.0.2'
  url 'http://www.github.com/bilel-kedidi/redmine_my_hours'
  author_url 'http://github.com/bilel-kedidi'

  project_module :my_hours do
    permission :view_my_hours, :my_hours => [:index]
  end
  menu :admin_menu, :billing_hours, {:controller => 'my_hours', :action => 'overview' },
       caption: :billing_hours

  menu :project_menu, :my_hours, {:controller => 'my_hours', :action => 'index' },
       caption: :my_hours,
       :if => Proc.new {
         User.current.allowed_to_globally?(:my_hours, {})
       },
       :after => :activity, param: :project_id



  Rails.application.config.to_prepare do
    Issue.send(:include, RedmineMyHours::IssuePatch)
    IssueQuery.send(:include, RedmineMyHours::IssueQueryPatch)
    Redmine::Export::PDF::IssuesPdfHelper.send(:include, RedmineMyHours::PdfPatch)
  end
end
