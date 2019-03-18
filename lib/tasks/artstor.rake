namespace :artstor do
   desc "One time task to add external metadata system info for JSTOR"
   task :add_ext_sys  => :environment do
      puts "Adding external metadata system for JSTOR..."
      ExternalSystem.create(name: "JSTOR", 
         public_url: "https://library.artstor.org", 
         api_url: "https://forum.jstor.org")
   end

   def create_or_find_collection(title)
      xm  = XmlMetadata.find_by(title: title)
      if !xm.nil?
         puts "a collection of this name already exists. ID: #{xm.id}"
         return xm
      else
         xml = 
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<mods xmlns=\"http://www.loc.gov/mods/v3\"
      xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"
      xmlns:mods=\"http://www.loc.gov/mods/v3\"
      xsi:schemaLocation=\"http://www.loc.gov/mods/v3
      http://www.loc.gov/standards/mods/v3/mods-3-3.xsd\">
   <titleInfo>
      <title>#{title}</title>
   </titleInfo>
</mods>"
         xm = XmlMetadata.create(desc_metadata: xml, availability_policy_id: 1, discoverability: false, 
            use_right_id: 1, dpla: false, ocr_hint_id: 2)
         puts "Create new JSTOR collection parent metadata record. ID: #{xm.id}"
         return xm
      end
   end

   # 16414
   desc "Link a unit with no metadata to JSTOR"
   task :link   => :environment do
      uid = ENV['unit']
      abort("Unit is required") if uid.blank?
      unit = Unit.find(uid)
      if unit.metadata.nil?
         title = ENV['title']
         md_id = ENV['collection_id']

         # if nothing specified for collection, default to Kore
         title = "Kore Collection" if title.blank? && md_id.blank?
         if !title.blank? 
            xml_collection_md = create_or_find_collection(title)
         else 
            xml_collection_md = XmlMetadata.find(md_id)
         end
         abort("Unable to create or find collection metadata #{title}") if xml_collection_md.nil?

         puts "Set unit[#{unit.id}] metadata to #{xml_collection_md.id}:#{xml_collection_md.title}"
         unit.update!(metadata: xml_collection_md)
      end

      puts "Link all master files to JSTOR records"
      js = ExternalSystem.find_by(name: "JSTOR")
      artstor_cookies = Jstor.start_public_session(js.public_url)

      unit.master_files.each do |mf| 
         next if !mf.metadata.nil? && mf.metadata_id != unit.metadata_id
         js_key = unit.master_files.first.filename.split(".").first 
         as_info = Jstor.find_public_info(js.public_url, js_key, artstor_cookies)
         if as_info.blank? 
            puts "WARN: No public info found for #{js_key}"
            next
         end
         uri = "/#/asset/#{as_info[:id]}"
         puts "Found public access URI: #{uri} : #{as_info[:title]}"
         em = ExternalMetadata.create!(external_system: js, external_uri: uri,
            use_right_id: 1, title: as_info[:title], parent_metadata_id: unit.metadata_id, ocr_hint_id: 2 )
         mf.update!(metadata: em)
         break
      end
      puts "DONE"
   end

   # generate the IIIF files for ARTSTOR masterfiles that lack them
   task :iiif  => :environment do
      puts "Publishing all missing IIIF files for *ARCH* master files..."
      cnt = 0
      missing_dirs = []
      MasterFile.where("filename like ?", "%arch%").find_each do |mf|
         if mf.iiif_exist? 
            #puts "MF #{mf.id} already has an IIIF JP2K file"
            next
         end

         # these files are only in the archive. Find them...
         # Note they are not archived by unit ID. Instead, they are archived 
         # by the part of the filename before the '_'
         unit_dir = mf.filename.split("_").first
         next if missing_dirs.include? unit_dir
         
         archive_dir = File.join(ARCHIVE_DIR, unit_dir)
         if !Dir.exist? archive_dir 
            puts "ERROR: Archive directory not found #{archive_dir}"
            missing_dirs << unit_dir
            next
         end

         archive_file = File.join(archive_dir, mf.filename)
         if !File.exist? archive_file 
            puts "ERROR: Archive file not found #{archive_file}"
            next
         end
         
         artstor_publish(archive_file, mf)
         cnt += 1
      end
      puts "Done. #{cnt} master files published to IIIF"
   end

   task :units  => :environment do
      puts "Publishing all missing files from units.txt..."
      cnt = 0
      units = File.read( "units.txt")
      missing_dirs = []
      units.split("\n").each do |uid|
         puts "Processing unit #{uid}"
         Unit.find(uid).master_files.each do |mf|
            next if mf.iiif_exist? 
            unit_dir = mf.filename.split("_").first
            next if missing_dirs.include? unit_dir
            
            archive_dir = File.join(ARCHIVE_DIR, unit_dir)
            if !Dir.exist? archive_dir 
               puts "ERROR: Archive directory not found #{archive_dir}"
               missing_dirs << unit_dir
               next
            end

            archive_file = File.join(archive_dir, mf.filename)
            if !File.exist? archive_file 
               puts "ERROR: Archive file not found #{archive_file}"
               next
            end
         
            artstor_publish(archive_file, mf)
            cnt += 1
         end
      end
      puts "Done. #{cnt} master files published to IIIF"
   end

   task :single  => :environment do
      puts "Publishing all missing IIIF files for 201206016ARCH  master files..."
      cnt = 0
      MasterFile.where("filename like ?", "201206016ARCH%").each do |mf|
         next if mf.iiif_exist? 
        
         unit_dir = "20120616ARCH"
         archive_dir = File.join(ARCHIVE_DIR, unit_dir)
         if !Dir.exist? archive_dir 
            abort "ERROR: Archive directory not found #{archive_dir}"
         end

         archive_file = File.join(archive_dir, mf.filename)
         if !File.exist? archive_file 
            puts "ERROR: Archive file not found #{archive_file}"
            next
         end
         
         artstor_publish(archive_file, mf)
         cnt += 1
      end
      puts "Done. #{cnt} master files published to IIIF"
   end

   def artstor_publish(orig_source, master_file) 
       source = orig_source
       # Generate a checksum if one does not already exist
       if master_file.md5.nil?
         source_md5 = Digest::MD5.hexdigest(File.read(source))
         master_file.update_attributes(:md5 => source_md5)
      end

      if master_file.filename.match(".tif$")
         # kakadu cant handle compression. remove it if detected
         cmd = "identify -quiet -ping -format '%C' #{source}[0]"
         compression = `#{cmd}`
         if compression != 'None'
            uncompressed_tmp = Tempfile.new([master_file.filename, ".tif"])
            dest_file = uncompressed_tmp.path
            cmd = "convert -compress none #{source} #{dest_file}"
            puts "Fixing compression with #{cmd}"
            `#{cmd}`
            source = dest_file
            puts "MasterFile #{master_file.id} is compressed.  This has been corrected automatically. New source is #{source}"
         end
      end

      # set path to IIIF jp2k storage location
      jp2k_path = master_file.iiif_file()
      jp2kdir = File.dirname(jp2k_path)
      if !Dir.exist?(jp2kdir)
         FileUtils.mkdir_p jp2kdir 
      end

      if master_file.filename.match(".jp2$")
         # write a JPEG-2000 file to the destination directory
         FileUtils.copy(source, jp2k_path)
         puts "Copied JPEG-2000 image using '#{source}' as input file for the creation of deliverable '#{jp2k_path}'"

      elsif source.match(/\.tiff?$/) and File.file?(source)
         # If the JP2k already exists (and is not 0), don't make it again!
         if File.exist?(jp2k_path) && File.size(jp2k_path) > 0
            puts "MasterFile #{master_file.id} already has JP2k file at #{jp2k_path}; skipping creation"
            return
         end

         # generate deliverables for DL use
         # As per a conversation with Ethan Gruber, I'm dividing the JP2K compression ratios between images that are greater and less than 500MB.
         executable = KDU_COMPRESS || %x( which kdu_compress ).strip
         if File.exist? executable
            `#{executable} -i #{source} -o #{jp2k_path} -rate 1.0,0.5,0.25 -num_threads #{NUM_JP2K_THREADS}`
            if !File.exist?(jp2k_path) || File.size(jp2k_path) == 0
               puts "ERROR: Destination #{jp2k_path} does not exist or is zero length"
            end
         else
            raise "kdu_compress missing"
         end

         puts "Generated JPEG-2000 image using '#{source}' as input file for the creation of deliverable '#{jp2k_path}'"
      else
         raise "Source is not a .tif or .jp2 file: #{source}"
      end
   end
end
