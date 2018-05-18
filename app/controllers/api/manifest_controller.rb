class Api::ManifestController < ApplicationController
   # Get a JSON listing of all master files that belong to the specified
   # PID. The PID can be from a metadata record or component
   #
   def show
      pid = params[:pid]

      # First, determine type - Metadata, Component or Metadata with appolo reference
      obj = Metadata.find_by(pid: pid)
      if !obj.blank?
         out = get_metadata_manifest(obj, params[:unit])
         render json: JSON.pretty_generate(out)
         return
      end

      obj = Component.find_by(pid: pid)
      if !obj.blank?
         out = get_component_manifest(obj)
         render json: JSON.pretty_generate(out)
         return
      end

      obj = SirsiMetadata.find_by(supplemental_system: "Apollo", supplemental_uri: "/collections/#{pid}")
      if !obj.blank?
         puts "This is an Apollo PID"
         out = get_apollo_manifest(obj.id)
         render json: JSON.pretty_generate(out)
         return
      end

      render plain: "PID #{pid} was not found", status: :not_found
   end

   private
   def get_apollo_manifest(parent_id)
      out  = []
      ExternalMetadata.where(parent_metadata_id: parent_id).each do |em|
         em.master_files.includes(:image_tech_meta).all.order(filename: :asc).each do |mf|
            json = { pid: mf.pid, filename: mf.filename, width: mf.image_tech_meta.width, height: mf.image_tech_meta.height }
            json[:title] = mf.title if !mf.title.nil?
            json[:description] = mf.description if !mf.description.nil?
            out << json
         end
      end
      return out
   end

   private
   def get_metadata_manifest(obj, unit_id)
      if !unit_id.nil?
   		logger.info("Only including masterfiles from unit #{unit_id}")
         files = obj.master_files.includes(:image_tech_meta).joins(:unit).where("units.id=?", unit_id).order(filename: :asc)
   	elsif obj.type == "ExternalMetadata" || !obj.supplemental_system.blank?
   		logger.info("This is External/supplemental metadata; including all master files")
         files = obj.master_files.includes(:image_tech_meta).all.order(filename: :asc)
   	else
   		logger.info("Only including masterfiles from units in the DL")
         files = obj.master_files.includes(:image_tech_meta).joins(:unit).where("units.include_in_dl=1").order(filename: :asc)
      end

      out  = []
      files.each do |mf|
         json = { pid: mf.pid, filename: mf.filename, width: mf.image_tech_meta.width, height: mf.image_tech_meta.height }
         json[:title] = mf.title if !mf.title.nil?
         json[:description] = mf.description if !mf.description.nil?
         out << json
      end
      return out
   end

   private
   def get_component_manifest(obj)
      out  = []
      obj.master_files.order(filename: :asc).each do |mf|
         json = { pid: mf.pid, filename: mf.filename, width: mf.image_tech_meta.width, height: mf.image_tech_meta.height }
         json[:title] = mf.title if !mf.title.nil?
         json[:description] = mf.description if !mf.description.nil?
         out << json
      end
      return out
   end

end
