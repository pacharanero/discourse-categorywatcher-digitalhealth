# name: WatchMutePlugin
# about: WatchMutePlugin - Watches or Mutes a category for all the users in a particular group
# version: 0.5
# authors: Adapted by Marcus Baw for Digital Health Networks, Arpit Jalan (original author)
# url: https://github.com/pacharanero/discourse-categorywatcher-digitalhealth

enabled_site_setting :watch_mute_enabled
enabled_site_setting :watch_mute_frequency_hours

PLUGIN_NAME ||= "watch_mute".freeze

module ::WatchMute

  # TODO: move this out into its own file as it will be needed by the tests
  WATCHES_MUTES = {
    "nz-ciln" => {
      "watch" => ["nz-network"],
      "mute" => ["faculty-of-clinical-informatics-open-channel", "open-forum", "public-forum"]
    },
    "nz-dig-leaders" => {
      "watch" => ["nz-network"],
      "mute" => ["faculty-of-clinical-informatics-open-channel", "open-forum", "public-forum"]
    },
  }

  def self.watch_mute_categories!
    WATCHES_MUTES.each do |group_name, data|              # iterate over the WATCHES_MUTES constant
      if group = Group.find_by_name(group_name)     # only if the group is valid
        group.users.each do |user|                  # iterate over all the users in the group
            # set the Watches
            data["watch"].each do |category_slug|
              category_id = Category.where(slug: category_slug).pluck(:id).first
              #Rails.logger.info "#{category_id}, #{category_name}, #{}user, #{CategoryUser.notification_levels[:watching]}"
              CategoryUser.set_notification_level_for_category(
                user, CategoryUser.notification_levels[:watching], category_id) unless CategoryUser.exists?(user_id: user.id, category_id: category_id)
                # 'unless' means if there's already a preference we don't override it
            end
            # set the Mutes
            data["mute"].each do |category_slug|
              category_id = Category.where(slug: category_slug).pluck(:id).first
              CategoryUser.set_notification_level_for_category(
                user, CategoryUser.notification_levels[:muted], category_id) unless CategoryUser.exists?(user_id: user.id, category_id: category_id)
                # 'unless' means if there's already a preference we don't override it
            end
          end
      else
        Rails.logger.warn "WatchMutePlugin: The group #{group_name} was not found on this server - watching and muted statues could not be set"
        # log that the group was not found
      end
    end
  end
end

after_initialize do
  module ::WatchMute

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace WatchMute
      Rails.logger.info 'WatchMutePlugin: The WatchMute Rails Engine was initialized'
    end

    class WatchMuteJob < ::Jobs::Scheduled
      every SiteSetting.watch_mute_frequency_hours.hours
      Rails.logger.info "WatchMutePlugin: The WatchMuteJob scheduled job has been set up to run every #{SiteSetting.watch_mute_frequency_hours} hours"

      def execute(args)
        Rails.logger.info 'WatchMutePlugin: The WatchMuteJob scheduled job ran'
        WatchMute.watch_mute_categories!
      end
    end
  end

end
