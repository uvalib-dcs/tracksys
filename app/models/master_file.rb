class MasterFile < ApplicationRecord
   enum text_source: {ocr: 0, corrected_ocr: 1, transcription: 2}

   #------------------------------------------------------------------
   # relationships
   #------------------------------------------------------------------
   has_and_belongs_to_many :tags, join_table: "master_file_tags"
   belongs_to :component, :counter_cache => true, optional: true
   belongs_to :unit
   belongs_to :metadata
   belongs_to :deaccessioned_by, class_name: "StaffMember",
              foreign_key: "deaccessioned_by_id", optional: true

   has_many :reorders, class_name: "MasterFile", foreign_key: "original_mf_id"
   belongs_to :original, class_name: "MasterFile",
              foreign_key: "original_mf_id", optional: true

   has_many :job_statuses, :as => :originator, :dependent => :destroy

   has_one :image_tech_meta, :dependent => :destroy
   has_one :order, :through => :unit
   has_one :customer, :through => :order
   has_one :academic_status, :through => :customer
   has_one :department, :through => :customer
   has_one :agency, :through => :order

   has_and_belongs_to_many :locations, join_table: "master_file_locations"

   #------------------------------------------------------------------
   # delegation
   #------------------------------------------------------------------
   delegate :container_id, :folder_id, :notes, to: :location, allow_nil: true, prefix: false
   delegate :title, :use_right, :to => :metadata, :allow_nil => true, :prefix => true

   delegate :date_due, :date_order_approved, :date_request_submitted, :date_customer_notified, :id,
      :to => :order, :allow_nil => true, :prefix => true

   delegate :id, :last_name,
      :to => :customer, :allow_nil => true, :prefix => true

   #------------------------------------------------------------------
   # validations
   #------------------------------------------------------------------
   validates :filename, :unit_id, :filesize, :presence => true
   validates :unit, :presence => {
      :message => "association with this Unit is no longer valid because it no longer exists."
   }

   #------------------------------------------------------------------
   # callbacks
   #------------------------------------------------------------------
   after_create do
      update_attribute(:pid, "tsm:#{self.id}")
   end

   after_create do
      Customer.increment_counter('master_files_count', self.customer.id)
      Order.increment_counter('master_files_count', self.order.id)
   end
   after_destroy do
      Customer.decrement_counter('master_files_count', self.customer.id)
      Order.decrement_counter('master_files_count', self.order.id)
   end

   #------------------------------------------------------------------
   # scopes
   #------------------------------------------------------------------
   scope :in_digital_library, ->{ where("master_files.date_dl_ingest is not null").order("master_files.date_dl_ingest ASC") }
   scope :not_in_digital_library, ->{ where("master_files.date_dl_ingest is null") }
   default_scope { order(filename: :asc) }

   #------------------------------------------------------------------
   # public class methods
   #------------------------------------------------------------------
   def location
      locations.first
   end
   def set_location( loc )
      update!(locations: [loc])
   end

   # Figure out the actual page number for this master file. It may not match the
   # filename numbering scheme if it MF metadata is different from the unit metadata
   def get_page_number
      # this is the normal case; masterfile and unit share same metadata record
      # so page number will match the numbering sequence of the filename
      page = filename.split("_")[1].split(".")[0].to_i
      # if metadata_id == unit.metadata_id
         if is_clone?
            mf_id = original_mf_id
            page = MasterFile.find(mf_id).filename.split("_")[1].split(".")[0].to_i
         end
      # else
      #    # this master file has been assigned to a separate metadata record. the
      #    # page number in the filename does not reflect the actual page num. Count
      #    # masterfiles owned by metadata record to determine
      #    page = 1
      #    metadata.master_files.each do |mf|
      #       if mf.id == id
      #          break
      #       else
      #          page += 1
      #       end
      #    end
      # end
      return page
   end

   def deaccessioned?
      return !self.deaccessioned_at.blank?
   end

   def in_dl?
      return self.date_dl_ingest?
   end

   def is_original?
      return self.original_mf_id.nil?
   end
   def is_clone?
      return !self.original_mf_id.nil?
   end

   # Within the scope of a current MasterFile's Unit, return the MasterFile object
   # that preceedes self.  Used to create links and relationships between objects.
   def previous
      master_files_sorted = self.sorted_set
      if master_files_sorted.find_index(self) > 0
         return master_files_sorted[master_files_sorted.find_index(self)-1]
      else
         return nil
      end
   end

   # Within the scope of a current MasterFile's Unit, return the MasterFile object
   # that follows self.  Used to create links and relationships between objects.
   def next
      master_files_sorted = self.sorted_set
      if master_files_sorted.find_index(self) < master_files_sorted.length
         return master_files_sorted[master_files_sorted.find_index(self)+1]
      else
         return nil
      end
   end

   def sorted_set
      master_files_sorted = self.unit.master_files.sort_by {|mf| mf.filename}
   end

   def ocr_candidate?
      return false if metadata.nil?
      return false if metadata.ocr_hint.nil?
      return metadata.ocr_hint.ocr_candidate
   end

   # Get full path to j2k file used by the IIIF server
   def iiif_file()
      pid_parts = pid.split(":")
      base = pid_parts[1]
      parts = base.scan(/../) # break up into 2 digit sections, but this leaves off last char if odd
      parts << base.last if parts.length * 2 !=  base.length
      pid_dirs = parts.join("/")
      jp2k_filename = "#{base}.jp2"
      jp2k_path = File.join(Settings.iiif_mount, pid_parts[0], pid_dirs)
      jp2k_path = File.join(jp2k_path, jp2k_filename)
      return jp2k_path
   end

   def link_to_image(image_size)
      image_pid = self.pid
      image_pid = self.original.pid if is_clone?
      iiif_url = nil
      rotate = "0"
      if !image_tech_meta.nil?
         #flip_y_axis: 1, rotate90: 2, rotate180: 3, rotate270
         rotate ="!0" if image_tech_meta.orientation == "flip_y_axis"
         rotate ="90" if image_tech_meta.orientation == "rotate90"
         rotate ="180" if image_tech_meta.orientation == "rotate180"
         rotate ="270" if image_tech_meta.orientation == "rotate270"
      end
      iiif_url = URI.parse("#{Settings.iiif_url}/#{image_pid}/full/!125,200/#{rotate}/default.jpg") if image_size == :small
      iiif_url = URI.parse("#{Settings.iiif_url}/#{image_pid}/full/!240,385/#{rotate}/default.jpg") if image_size == :medium
      iiif_url = URI.parse("#{Settings.iiif_url}/#{image_pid}/full/,640/#{rotate}/default.jpg") if image_size == :large
      iiif_url = URI.parse("#{Settings.iiif_url}/#{image_pid}/full/full/#{rotate}/default.jpg") if image_size == :full
      raise "Invalid size" if iiif_url.nil?
      return iiif_url.to_s
   end

   def add_new_tag(tag)
      exist = Tag.find_by(tag: tag)
      if exist.nil?
         new_tag = Tag.create(tag: tag)
         self.tags << new_tag
         return new_tag
      else
         tags << exist
         return exist
      end
   end

   def add_tags(tag_ids)
      added = []
      tag_ids.each do |tag_id|
         next if tag_id.blank?
         t = Tag.find(tag_id)
         if !self.tags.include? t
            self.tags << t
            added << t
         end
      end
      return added
   end
end

# == Schema Information
#
# Table name: master_files
#
#  id                  :integer          not null, primary key
#  unit_id             :integer          default(0), not null
#  component_id        :integer
#  filename            :string(255)
#  filesize            :integer
#  title               :string(255)
#  date_archived       :datetime
#  description         :text(65535)
#  pid                 :string(255)
#  created_at          :datetime
#  updated_at          :datetime
#  transcription_text  :text(65535)
#  md5                 :string(255)
#  date_dl_ingest      :datetime
#  date_dl_update      :datetime
#  creation_date       :string(255)
#  primary_author      :string(255)
#  metadata_id         :integer
#  original_mf_id      :integer
#  deaccessioned_at    :datetime
#  deaccession_note    :text(65535)
#  deaccessioned_by_id :integer
#  text_source         :integer
#  exemplar            :boolean          default(FALSE)
#
