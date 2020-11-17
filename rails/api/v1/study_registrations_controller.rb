# frozen_string_literal: true

module Api
  module V1
    class StudyRegistrationsController < BaseController
      before_action :find_study, only: :create
      FIRST_STUDY_MATERIAL = 0
      NEXT_DAY = 1
      NUMBER_OF_WEEK = 7
      def create
        add_user_in_params
        study_reg = UserStudyPreRegistration.new(reg_params)
        ActiveRecord::Base.transaction do
          if study_reg.save
            generate_user_notifications
            add_notification_number
            render json: success_response(message: I18n.t('success.success_message'))
          else
            render_error(message: I18n.t('failure.something_went_wrong'),
                         error_code: :unprocessable_entity,
                         status_code: :unprocessable_entity)
            Rollbar.error(I18n.t('failure.error_in_obj_on_saving', class_name: study_reg.class.name),
                          object_info: study_reg,
                          errors: study_reg.errors.messages)
          end
        end
      rescue ActiveRecord::RecordNotUnique => e
        render_error(message: I18n.t('failure.already_reg'),
                     error_code: :unprocessable_entity,
                     status_code: :unprocessable_entity)
      rescue Exception => e
        render_error(message: I18n.t('failure.something_went_wrong'),
                     error_code: :unprocessable_entity,
                     status_code: :unprocessable_entity)
        Rollbar.error(e.message,
                      object_info: study_reg)
      end

      private

      def add_notification_number
        study_notifications = @api_current_user.user_notifications.where(study_id: params.dig(:pre_reg, :study_id)).order(notification_time: :asc)
        parent_notifications = study_notifications.where(reminder: false)
        number_of_notification = parent_notifications.count
        parent_notifications.each_with_index do |notification, index|
          notification_number = "#{index + 1}/#{number_of_notification}"
          notification.update!(number: notification_number)
          reminders = study_notifications.where(reminder: true, notification_parent_id: notification.id)
          reminders.each do |reminder|
            reminder.update!(number: notification_number)
          end
        end
      end

      def generate_user_notifications
        if find_study.same_study_material
          frequency.times do |frequency|
            same_study_material(frequency)
          end
        else
          diff_study_material
        end
      end

      def frequency
        @frequency ||= find_study.frequency
      end

      def number_of_notification
        @number_of_notification ||= find_study.number_of_notification
      end

      def same_study_material(frequency)
        number_of_notification.times do |index|
          notification = find_notification(index)
          create_parent_notification_and_remainders(notification, index, frequency)
        end
      end

      def diff_study_material
        index_counter = 0
        frequency.times do |frequency|
          number_of_notification.times do |number_of_notification_index|
            material_index = find_study.same_notification ? number_of_notification_index : index_counter
            create_notifications_if_diff_material(material_index, frequency)
            index_counter += 1
          end
        end
      end

      def create_parent_notification_and_remainders(notification, study_detail_index, frequency)
        notification_time = notification_time_with_date(notification, frequency, study_detail_index)
        parent_notification = create_parent_notification(notification_time, study_detail_index)
        if notification.number_of_reminders.present?
          create_remainders(notification, parent_notification, notification_time, study_detail_index)
        end
      end

      def notification_time_with_date(notification, frequency, study_detail_index)
        notification_time = if random_notification?(notification)
                              generate_random_time(notification, study_detail_index)
                            else
                              notification&.start_time
                            end
        join_date_with_time(notification_time, frequency, notification)
      end

      def random_notification?(notification)
        notification.type == StudyGroupNotification::RANDOM_NOTIFICATION
      end

      def generate_random_time(notification, study_detail_index)
        if find_study.study_group_notifications.first.participant_specified
          user_selected_time(study_detail_index)
        else
          rand(notification.start_time..notification.end_time)
        end
      end

      def user_selected_time(study_detail_index)
        if find_study.split_week
          select_start_end_time(study_detail_index)
        else
          random_time('start_time', 'end_time')
        end
      end

      def select_start_end_time(notification_index)
        if notification_index < study_group_notifications.first.weekly_notifications
          random_time('start_time', 'end_time')
        else
          random_time('split_start_date', 'split_end_date')
        end
      end

      def random_time(start_time, end_time)
        rand((params.dig(:pre_reg, start_time.to_sym).to_time(:utc))..(params.dig(:pre_reg, end_time.to_sym).to_time(:utc)))
      end

      def ema_weekly_notification(notification)
        random_weekday = select_week_day(notification)
        number_of_week = StudyGroupNotification::NUMBER_OF_WEED_DAY[random_weekday.to_sym]
        week_start = select_start_day.wday > number_of_week ? select_start_day.next_week : select_start_day.beginning_of_week
        week_start.advance(days: StudyGroupNotification::NUMBER_OF_WEED_DAY[random_weekday.to_sym])
      end

      def select_start_day
        if find_study.pre_registration_required
          find_study.start_date.to_date
        else
          params.dig(:pre_reg, :reg_date).to_date
        end
      end

      def select_week_day(notification)
        if notification.type == StudyGroupNotification::RANDOM_NOTIFICATION
          notification.week_days.map { |week_day, value| week_day if value == 'true' }.compact.sample
        else
          notification.week_days.select { |week_day, value| week_day if value == 'true' }.keys.first
        end
      end

      def create_parent_notification(notification_time, study_detail_index)
        @api_current_user.user_notifications.create!(
          study_id: find_study.id,
          notification_time: notification_time,
          study_detail_index: study_detail_index(study_detail_index),
          reminder: false
        )
      end

      def study_detail_index(study_detail_index)
        find_study.same_study_material ? FIRST_STUDY_MATERIAL : study_detail_index
      end

      def create_remainders(notification, parent_notification, notification_time, study_detail_index)
        notification.number_of_reminders.times do |reminder_index|
          parent_notification.reminders.create!(
            user_id: @api_current_user.id,
            study_id: find_study.id,
            notification_time: (notification_time + ((notification.reminder_spacing * 60) * (reminder_index + 1))),
            reminder: true,
            study_detail_index: study_detail_index(study_detail_index)
          )
        end
      end

      def create_notifications_if_diff_material(number_of_notification_index, frequency)
        notification = notification_for_diff_material(number_of_notification_index)
        create_parent_notification_and_remainders(notification, number_of_notification_index, frequency)
      end

      def find_study
        @find_study ||= Study.find_by(id: params.dig(:pre_reg, :study_id))
      end

      def notification_for_diff_material(number_of_notification_index)
        if find_study.same_notification
          find_notification(number_of_notification_index)
        else
        find_different_notification(number_of_notification_index)
      end
    end

      def study_group_notifications
        @study_group_notifications ||= find_study.study_group_notifications
      end

      # In case of study have same notifications
      def find_notification(index)
        notifications = study_group_notifications
        if random_notification?(notifications.first)
          random_notification(notifications, index)
        else
          notifications[index]
        end
      end

      def random_notification(notifications, index)
        if find_study.same_notification
          select_notification(notifications, index)
        else
          notifications[index]
        end
      end

      def select_notification(notifications, index)
        if find_study.split_week
          split_notification(notifications, index)
        else
          notifications.first
        end
      end

      def split_notification(notifications, index)
        if index < notifications.first.weekly_notifications
          notifications.first
        else
          notifications.second
        end
      end

      # In case of study have different notifications
      def find_different_notification(index)
        find_study.study_details[index].study_group_notifications.first
      end

      def add_user_in_params
        params[:pre_reg][:user_id] = @api_current_user.id
      end

      def reg_params
        params.require(:pre_reg).permit(:user_id,
                                        :study_id,
                                        :reg_date,
                                        :start_time,
                                        :end_time,
                                        :random_time,
                                        :split_start_date,
                                        :split_end_date)
      end

      def select_day(notification, user_reg_date, frequency)
        if Study.ema_weekly?(find_study)
          ema_weekly_notification(notification) + (frequency * NUMBER_OF_WEEK).day
        else
          user_reg_date + NEXT_DAY.day + frequency.day
        end
      end

      def select_date(notification, user_reg_date, frequency)
        if find_study.start_date?
          select_day_with_start_date(notification, frequency)
        else
          select_day(notification, user_reg_date, frequency)
        end
      end

      def select_day_with_start_date(notification, frequency)
        if Study.ema_weekly?(find_study)
          ema_weekly_notification(notification) + (frequency * NUMBER_OF_WEEK).day
        else
          find_study.start_date + frequency.day
        end
      end

      def join_date_with_time(notification_time, frequency, notification)
        user_reg_date = @api_current_user.user_study_pre_registrations.find_by(study_id: find_study.id)&.reg_date
        date = select_date(notification, user_reg_date, frequency)
        notification_time.change(year: date&.year, month: date&.month, day: date.day)
      end
    end
  end
end
