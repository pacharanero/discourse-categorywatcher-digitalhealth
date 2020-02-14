# name: discourse-watchmute
# about: discourse-watchmute - Watches or Mutes a category for all the users in a particular group
# version: 0.6.0
# authors: Adapted by Marcus Baw for Digital Health Networks, original author Arpit Jalan
# url: https://github.com/pacharanero/discourse-watchmute

enabled_site_setting :watch_mute_enabled
enabled_site_setting :watch_mute_frequency_hours

PLUGIN_NAME ||= 'watch_mute'.freeze

module ::WatchMute

  # TODO: move this out into its own file

  WATCHES_MUTES = {
    'nz-ciln' => {
      'nz-forum' => :watching_first_post,
      'faculty-of-clinical-informatics-open-channel' => :muted,
      'open-forum' => :muted,
      'public' => :muted,
      'nz' => :watching_first_post,
      'nz-important' => :watching,
    },
    'nz-dig-leaders' => {
      'nz-forum' => :watching_first_post,
      'faculty-of-clinical-informatics-open-channel' => :muted,
      'open-forum' => :muted,
      'public' => :muted,
      'nz' => :watching_first_post,
      'nz-important' => :watching,
    },
    'nz-si' => {
      'south-island' => :watching,
    },
    # 'Caffe-Inf-members' => {
    #   'nz-network' => :watching_first_post,
    #   'faculty-of-clinical-informatics-open-channel' => :muted,
    #   'open-forum' => :muted,
    #   'public' => :muted,
    #   'nz' => :watching_first_post,
    #   'nz-important' => :watching,
    # },
  }

  def self.watch_mute_categories!
    WATCHES_MUTES.each do |group_name, data|        # iterate over the WATCHES_MUTES constant
      if group = Group.find_by_name(group_name)    # only if the group is valid
        group.users.each do |user|                  # iterate over all the users in the group
          # set the Watches
          data.each do |slug, desired_notification_level|
            # assume the slug is a Category, but try Tags next
            if category_id = Category.where(slug: slug).pluck(:id).first

              CategoryUser.set_notification_level_for_category(
                user, CategoryUser.notification_levels[desired_notification_level], category_id) unless CategoryUser.exists?(user_id: user.id, category_id: category_id)
                # 'unless' means if there's already a preference we don't override it
                # remove the unless if you want it to overwrite existing prefs (and annoy your users)

            elsif tag_id = Tag.where(name: slug).pluck(:id).first
              # if it isn't a Category, try looking it up as a Tag
              Rails.logger.info "discourse-watchmute: The Tag #{slug} was found on this server - watching and muting statuses will now be set"

              TagUser.change(
                user, tag_id, TagUser.notification_levels[desired_notification_level]) unless TagUser.exists?(user_id: user.id, tag_id: tag_id)
              # 'unless' means if there's already a preference we don't override it
              # remove the unless if you want it to overwrite existing prefs (and annoy your users)

            else
              # the slug isn't a Category OR a Tag - fail but log it.
              Rails.logger.warn "discourse-watchmute: The Category or Tag #{slug} was not found on this server - watching and muted statuses could not be set"
            end
          end
        end

      else
        # else log that the group was not found
        Rails.logger.warn "discourse-watchmute: The group #{group_name} was not found on this server - watching and muted statuses could not be set"
      end
    end
  end
end

after_initialize do
  module ::WatchMute

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace WatchMute
      Rails.logger.info 'discourse-watchmute: The WatchMute Rails Engine was initialized'
    end

    class WatchMuteJob < ::Jobs::Scheduled
      every SiteSetting.watch_mute_frequency_hours.hours
      Rails.logger.info "discourse-watchmute: The WatchMuteJob scheduled job has been set up to run every #{SiteSetting.watch_mute_frequency_hours} hours"

      def execute(args)
        Rails.logger.info 'discourse-watchmute: The WatchMuteJob scheduled job ran'
        WatchMute.watch_mute_categories!
      end
    end
  end

end
