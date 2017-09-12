class MoveCompletedDirectoryToDeleteDirectory < BaseJob
   require 'fileutils'

   def do_workflow(message)

      unit_id = message[:unit_id]
      unit = Unit.find(unit_id)
      source_dir = message[:source_dir]

      if message[:unit_dir]
         unit_dir = message[:unit_dir]
      else
         unit_dir = "%09d" % unit_id
      end

      if !Dir.exists? source_dir
         on_success "Source directory #{source_dir} has already been removed"
         return
      end

      # Unit update?
      if /unit_update/ =~ source_dir
         del_dir = unit.get_finalization_dir(:delete_from_update)
         if Dir.exists? del_dir
            del_dir = del_dir.chomp("/")    # remove the trailing slash if present
            del_dir << Time.now.to_i.to_s   # add a timestamp
         end
         FileUtils.mv source_dir, del_dir
         on_success "All update files for unit #{unit_id} have been moved to #{del_dir}."

      # If source_dir matches the finalization in process dir, move to delet and look for items in /scan
      elsif /20_in_process/ =~ source_dir
         del_dir = unit.get_finalization_dir(:delete_from_finalization)
         FileUtils.mv source_dir, del_dir
         logger.info "All files associated with #{unit_dir} has been moved to #{del_dir}."

         # Once the files are moved from IN_PROCESS_DIR, dump all scan directories too
         unit.get_scan_dirs.each do |scan_dir|
            if  Dir.exists? scan_dir
               del_dir = scan_dir.gsub(/scan/, "ready_to_delete/from_scan")
               FileUtils.mv scan_dir, del_dir
               logger.info "Scan files from #{scan_dir} have been moved to #{del_dir}."
            end
         end
      else
         on_error "There is an error in the message sent to move_completed_directory_to_delete_directory.  The source_dir variable is set to an unknown value: #{source_dir}."
      end
   end
end
