# This code is based on Thoughtbot's guide to migrating from Paperclip
# to Active Storage:
# https://github.com/thoughtbot/paperclip/blob/master/MIGRATING.md
namespace :active_storage do
  desc "Copy paperclip's attachment database columns to active storage"
  task migrate_from_paperclip: :environment do
    logger = ApplicationLogger.new

    ActiveRecord::Base.connection.raw_connection.prepare("active_storage_statement", <<-SQL)
      with rows as(
        INSERT INTO active_storage_blobs (
          key, filename, content_type, metadata, byte_size, checksum, created_at
        ) VALUES ($1, $2, $3, '{}', $4, $5, $6) RETURNING id
      )
      INSERT INTO active_storage_attachments (
        name, record_type, record_id, blob_id, created_at
      ) VALUES ($7, $8, $9, (SELECT id FROM rows), $10)
    SQL

    Rails.application.eager_load!
    models = ActiveRecord::Base.descendants.reject(&:abstract_class?)

    ActiveRecord::Base.transaction do
      models.each do |model|
        next if model.name == "OldPassword" && !model.table_exists?

        attachments = model.column_names.map do |c|
          if c =~ /(.+)_file_name$/
            $1
          end
        end.compact

        if attachments.blank?
          next
        end

        model.find_each.each do |instance|
          attachments.each do |attachment|
            next if instance.send(attachment).path.blank?

            ActiveRecord::Base.connection.raw_connection.exec_prepared(
              "active_storage_statement", [
                SecureRandom.uuid, # Alternatively instance.send("#{attachment}_file_name"),
                instance.send("#{attachment}_file_name"),
                instance.send("#{attachment}_content_type"),
                instance.send("#{attachment}_file_size"),
                Digest::MD5.base64digest(File.read(instance.send(attachment).path)),
                instance.updated_at.iso8601,
                "storage_#{attachment}",
                model.name,
                instance.id,
                instance.updated_at.iso8601
              ])
          end
        end
      end
    end

    ActiveStorage::Attachment.find_each do |attachment|
      dest = ActiveStorage::Blob.service.path_for(attachment.blob.key)
      name = attachment.name.gsub("storage_", "")
      source = attachment.record.send(name).path

      FileUtils.mkdir_p(File.dirname(dest))
      logger.info "Copying #{source} to #{dest}"
      FileUtils.cp(source, dest)
    end
  end
end
