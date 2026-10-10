module AdminPortal
  # A second admin dashboard, generated with `pu:dashboard`, so the sidebar's
  # Dashboards group lists more than one entry.
  class ContentDashboard < Plutonium::Dashboard::Base
    presents label: "Content", description: "What the blog is publishing", icon: Phlex::TablerIcons::Article

    filter :status, choices: {"all" => "All posts", "published" => "Published", "draft" => "Drafts"}, default: "all"
    link :posts, label: "All posts", icon: Phlex::TablerIcons::FileText, href: -> { resource_url_for(::Blogging::Post, parent: nil) }
    link :hidden, href: "/nowhere", condition: -> { false }

    metric(:posts, span: 4, icon: Phlex::TablerIcons::FileText, href: -> { resource_url_for(::Blogging::Post, parent: nil) }) do
      posts.count
    end

    metric(:comments, span: 4, icon: Phlex::TablerIcons::Message) { authorized_resource_scope(Comment).count }

    metric(:flagged, span: 4, positive: :down, description: "Comments awaiting review") do
      authorized_resource_scope(Comment).where(flagged: true).count
    end

    chart(:by_status, type: :column, span: :full) do
      posts.group(:status).count.transform_keys { |status| status.to_s.titleize }
    end

    private

    def posts
      scope = authorized_resource_scope(::Blogging::Post)
      (filter_value(:status) == "all") ? scope : scope.where(status: filter_value(:status))
    end
  end
end
