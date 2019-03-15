# name: Watch Category
# about: Watches a category for all the users in a particular group
# version: 0.2
# authors: Arpit Jalan (original author), adapted by Marcus Baw for Digital Health Networks
# url: https://github.com/discourse/discourse-watch-category-mcneel

module ::WatchCategory
  def self.watch_category!
    nz_network_category = Category.find_by_slug("nz-network")
    nz_network_group = Group.find_by_name("nz-network")

    unless nz_network_category.nil? || nz_network_group.nil?
      nz_network_group.users.each do |user|
        watched_categories = CategoryUser.lookup(user, :watching).pluck(:category_id)
        CategoryUser.set_notification_level_for_category(user, CategoryUser.notification_levels[:watching], nz_network_category.id) unless watched_categories.include?(nz_network_category.id)
      end
    end
  end
end

after_initialize do
  module ::WatchCategory
    class WatchCategoryJob < ::Jobs::Scheduled
      every 1.day

      def execute(args)
        WatchCategory.watch_category!
      end
    end
  end
end
