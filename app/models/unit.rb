class Unit < ActiveRecord::Base

   UNIT_STATUSES = %w[approved canceled condition copyright unapproved]

   # The request form requires having data stored temporarily to the unit model and
   # then concatenated into special instructions.  Those fields are:
   attr_accessor :request_call_number, :request_copy_number, :request_volume_number,
      :request_issue_number, :request_location, :request_title, :request_author, :request_year,
      :request_description, :request_pages_to_digitize

   #------------------------------------------------------------------
   # relationships
   #------------------------------------------------------------------
   belongs_to :metadata, polymorphic: true   # NOTE: must manually handle counter cache

   belongs_to :intended_use, :counter_cache => true
   belongs_to :indexing_scenario, :counter_cache => true
   belongs_to :order, :counter_cache => true, :inverse_of => :units

   has_many :master_files
   has_many :components, :through => :master_files
   has_many :job_statuses, :as => :originator, :dependent => :destroy

   has_one :agency, :through => :order
   has_one :customer, :through => :order

   # FIXME non-polymorphic reference to metadata!!
   # delegate :call_number, :title, :catalog_key, :barcode, :pid, :exemplar,
   #    :to => :bibl, :allow_nil => true, :prefix => true
   delegate :id, :full_name,
      :to => :customer, :allow_nil => true, :prefix => true
   delegate :date_due,
      :to => :order, :allow_nil => true, :prefix => true
   delegate :deliverable_format, :deliverable_resolution, :deliverable_resolution_unit,
      :to => :intended_use, :allow_nil => true, :prefix => true

   has_and_belongs_to_many :legacy_identifiers

   scope :to_future_events, lambda { self.to_events.joins
      ("join events on events.id = invites.inviteable_id").where('events.starttime > ?', Time.now) }


   #------------------------------------------------------------------
   # scopes
   #------------------------------------------------------------------
   scope :in_repo, ->{where("date_dl_deliverables_ready IS NOT NULL").order("date_dl_deliverables_ready DESC") }
   scope :sirsi_ready_for_repo, -> {
      where(include_in_dl: true).where(date_queued_for_ingest: nil).where.not(date_archived: nil)
      .joins("inner join sirsi_metadata on sirsi_metadata.id=metadata_id").where.not(:"sirsi_metadata.availability_policy_id"=>nil)
   }
   scope :xml_ready_for_repo, -> {
      where(include_in_dl: true).where(date_queued_for_ingest: nil).where.not(date_archived: nil)
      .joins("inner join xml_metadata on xml_metadata.id=metadata_id").where.not(:"xml_metadata.availability_policy_id"=>nil)
   }
   scope :ready_for_repo, -> {
      sirsi_ready_for_repo.or(xml_ready_for_repo)
   }
   scope :awaiting_copyright_approval, ->{where(:unit_status => 'copyright') }
   scope :awaiting_condition_approval, ->{where(:unit_status => 'condition') }
   scope :approved, ->{where(:unit_status => 'approved') }
   scope :unapproved, ->{where(:unit_status => 'unapproved') }
   scope :canceled, ->{where(:unit_status => 'canceled') }
   scope :overdue_materials, ->{where("date_materials_received IS NOT NULL AND date_archived IS NOT NULL AND date_materials_returned IS NULL").where('date_materials_received >= "2012-03-01"') }
   scope :checkedout_materials, ->{where("date_materials_received IS NOT NULL AND date_materials_returned IS NULL").where('date_materials_received >= "2012-03-01"') }
   scope :uncompleted_units_of_partially_completed_orders, ->{includes(:order).where(:unit_status => 'approved', :date_archived => nil).where('intended_use_id != 110').where('orders.date_finalization_begun is not null').references(:order) }


   #------------------------------------------------------------------
   # validations
   #------------------------------------------------------------------
   validates_presence_of :order
   validates :patron_source_url, :format => {:with => URI::regexp(['http','https'])}, :allow_blank => true
   validates :metadata, :presence => true
   validates :intended_use, :presence => {
      :message => "must be selected."
   }
   validates :indexing_scenario, :presence => {
      :if => 'self.indexing_scenario_id',
      :message => "association with this IndexingScenario is no longer valid because it no longer exists."
   }
   validates :order, :presence => {
      :if => 'self.order_id',
      :message => "association with this Order is no longer valid because it no longer exists."
   }

   #------------------------------------------------------------------
   # callbacks
   #------------------------------------------------------------------
   before_save do
      # boolean fields cannot be NULL at database level
      self.exclude_from_dl = 0 if self.exclude_from_dl.nil?
      self.include_in_dl = 0 if self.include_in_dl.nil?
      self.master_file_discoverability = 0 if self.master_file_discoverability.nil?
      self.order_id = 0 if self.order_id.nil?
      self.remove_watermark = 0 if self.remove_watermark.nil?
      self.unit_status = "unapproved" if self.unit_status.nil? || self.unit_status.empty?
   end
   after_update :check_order_status, :if => :unit_status_changed?

   #------------------------------------------------------------------
   # aliases
   #------------------------------------------------------------------
   # Necessary for Active Admin to poplulate pulldown menu
   alias_attribute :name, :id

   #------------------------------------------------------------------
   # public class methods
   #------------------------------------------------------------------

   #------------------------------------------------------------------
   # public instance methods
   #------------------------------------------------------------------
   def approved?
      if self.unit_status == "approved"
         return true
      else
         return false
      end
   end

   def canceled?
      if self.unit_status == "canceled"
         return true
      else
         return false
      end
   end

   def in_dl?
      return self.date_dl_deliverables_ready?
   end

   def ready_for_repo?
      return false if self.include_in_dl == false
      return false if self.availability_policy_id.nil?
      return true if self.date_queued_for_ingest.nil? and not self.date_archived.nil?
      return false
   end

   def check_order_status
      if self.order.ready_to_approve?
         self.order.order_status = 'approved'
         self.order.date_order_approved = Time.now
         self.order.save!
      end
   end

   # Within the scope of a Unit's order, return the Unit which follows
   # or precedes the current Unit sequentially.
   def next
      units_sorted = self.order.units.sort_by {|unit| unit.id}
      if units_sorted.find_index(self) < units_sorted.length
         return units_sorted[units_sorted.find_index(self)+1]
      else
         return nil
      end
   end

   def previous
      units_sorted = self.order.units.sort_by {|unit| unit.id}
      if units_sorted.find_index(self) > 0
         return units_sorted[units_sorted.find_index(self)-1]
      else
         return nil
      end
   end

   def check_unit_delivery_mode
      CheckUnitDeliveryMode.exec( {:unit => self} )
   end

   def get_from_stornext(computing_id)
      CopyArchivedFilesToProduction.exec( {:unit => self, :computing_id => computing_id })
   end

   def import_unit_iview_xml
      unit_dir = "%09d" % self.id
      ImportUnitIviewXML.exec( {:unit => self, :path => "#{IN_PROCESS_DIR}/#{unit_dir}/#{unit_dir}.xml"})
   end

   def qa_filesystem_and_iview_xml
      QaFilesystemAndIviewXml.exec( {:unit => self} )
   end

   def qa_unit_data
      QaUnitData.exec( {:unit => self})
   end

   def send_unit_to_archive
      SendUnitToArchive.exec( {:unit => self, :internal_dir => true, :source_dir => "#{IN_PROCESS_DIR}"})
   end

   def start_ingest_from_archive
      StartIngestFromArchive.exec( {:unit => self })
   end

   def legacy_identifier_links
      return "" if self.legacy_identifiers.empty?
      out = ""
      self.legacy_identifiers.each do |li|
         out << "<div><a href='/admin/legacy_identifiers/#{li.id}'>#{li.description} (#{li.legacy_identifier})</a></div>"
      end
      return out
  end
end

# == Schema Information
#
# Table name: units
#
#  id                             :integer          not null, primary key
#  order_id                       :integer          default(0), not null
#  bibl_id                        :integer
#  unit_status                    :string(255)
#  date_materials_received        :datetime
#  date_materials_returned        :datetime
#  unit_extent_estimated          :integer
#  unit_extent_actual             :integer
#  patron_source_url              :text(65535)
#  special_instructions           :text(65535)
#  created_at                     :datetime
#  updated_at                     :datetime
#  intended_use_id                :integer
#  exclude_from_dl                :boolean          default(FALSE), not null
#  staff_notes                    :text(65535)
#  date_queued_for_ingest         :datetime
#  date_archived                  :datetime
#  date_patron_deliverables_ready :datetime
#  include_in_dl                  :boolean          default(FALSE)
#  date_dl_deliverables_ready     :datetime
#  remove_watermark               :boolean          default(FALSE)
#  master_file_discoverability    :boolean          default(FALSE)
#  indexing_scenario_id           :integer
#  checked_out                    :boolean          default(FALSE)
#  master_files_count             :integer          default(0)
#
