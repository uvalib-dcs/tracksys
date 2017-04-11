class Step < ActiveRecord::Base
   enum step_type: [:start, :end, :error, :normal]
   enum owner_type: [:any_owner, :prior_owner, :unique_owner, :original_owner, :supervisor_owner]

   validates :name, :presence => true

   belongs_to :workflow
   belongs_to :next_step, class_name: "Step"
   belongs_to :fail_step, class_name: "Step"
   has_many :notes

   # Perform end of step validation and automation
   #
   def finish( project )
      # For manual steps, just validate the destingation directory
      if self.manual
         return validate_finish_dir( project )
      end

      # Make sure no illegal/stopper files are present in the starting directory
      # NOTE: The validation will be skipped if no start directory is found. This
      # is needed to handle error recovery when a automatic move failed and the
      # user manually moved files to finsh dir befor finish clicked
      Rails.logger.info "Validate start files for project #{project.id}, step #{project.current_step.id}"
      return false if !validate_start_files(project)

      # Automatically move files to destination directory
      return move_files( project )
   end

   private
   def validate_start_files(project)
      # Error steps are all manual so start dir cannot be validated (it wont exist)
      return true if self.error?

      unit_dir = "%09d" % project.unit.id
      start_dir =  File.join("#{PRODUCTION_MOUNT}", self.start_dir, unit_dir)

      # if start dir doesnt exist, assume it has been manually moved.
      return true if !Dir.exists?(start_dir)

      # Base start directory is present, see if it also contains an output directory. If
      # it does, use it as the directory to validate.
      output_dir =  File.join(start_dir, "Output")
      start_dir = output_dir if Dir.exists? output_dir
      return validate_directory_content(project, start_dir)
   end

   private
   def step_failed(project, msg)
      prob = Problem.find_by(name: "Filesystem")
      Note.create(staff_member: project.owner, project: project, note_type: :problem, note: msg, problem: prob, step: project.current_step )
      project.active_assignment.update(status: :error )
   end

   private
   def validate_directory_content(project, dir)
      # Make sure the names match the unit & highest number is the same as the count
      highest = -1
      cnt = 0
      unit_dir = "%09d" % project.unit.id
      Dir[File.join(dir, '*.tif')].each do |f|
         name = File.basename f,".tif" # get name minus extention
         num = name.split("_")[1].to_i
         cnt += 1
         highest = num if num > highest
         if name.split("_")[0] != unit_dir
            step_failed(project, "<p>Found incorrectly named image file #{f}.</p>")
            return false
         end
      end
      if cnt == 0
         step_failed(project, "<p>No image files found in #{dir}</p>")
         return false
      end
      if highest != cnt
         step_failed(project, "<p>Number of image files does not match highest image sequence number #{highest}.</p>")
         return false
      end

      # Make sure there is at most 1 mpcatalog file
      cnt = 0
      Dir[File.join(dir, '*.mpcatalog')].each do |f|
         cnt += 1
         if cnt > 1
            step_failed(project, "<p>Found more than one .mpcatalog file.</p>")
            return false
         end

         name = File.basename f,".mpcatalog"
         if name != unit_dir
            step_failed(project, "<p>Found incorrectly named .mpcatalog file #{f}.</p>")
            return false
         end
      end

      # once NEXT step has a failure path (meaning it is a QA step),
      # fail current step if there is no mpcatalog
      next_step = project.current_step.next_step
      if cnt == 0 && !next_step.nil? && !next_step.fail_step.blank?
         step_failed(project, "<p>Missing #{unit_dir}.mpcatalog file</p>")
         return false
      end

      #  *.mpcatalog_* can be left over if the project was not saved. If any are
      # found, fail the step and prompt user to save changes and clean up
      if Dir[File.join(dir, '*.mpcatalog_*')].count { |file| File.file?(file) } > 0
         prob = Problem.find_by(name: "Filesystem")
         step_failed(project, "<p>Found *.mpcatalog_* files in #{start_dir}. Please ensure that you have no unsaved changes and delete these files.</p>")
         return false
      end

      # On the final step, be sure there is an XML file present that
      # has a name matching the unit directory
      if self.end?
         Rails.logger.info("Final step validations; look for unit.xml file and ensure no unexpected files exist")
         if !File.exists? File.join(dir, "#{unit_dir}.xml")
            step_failed(project, "<p>Missing #{unit_dir}.xml</p>")
            return false
         end

         # Make sure only .tif, .xml and .mpcatalog files are present. Fail if others
         Dir[File.join(dir, '*')].each do |f|
            ext = File.extname f
            ext.downcase!
            if ext != ".xml" && ext != ".tif" && ext != ".mpcatalog"
               step_failed(project, "<p>Unexpected file or directory #{f} found</p>")
               return false
            end
         end
      end

      return true
   end

   private
   def validate_finish_dir(project)
      unit_dir = "%09d" % project.unit.id
      dest_dir =  File.join("#{PRODUCTION_MOUNT}", self.finish_dir, unit_dir)
      Rails.logger.info("Validate files present in #{dest_dir}")

      if !Dir.exists?(dest_dir)
         Rails.logger.error("Finish firectory #{dest_dir} does not exist")
         step_failed(project, "<p>Finish directory #{dest_dir} does not exist</p>")
         return false
      end

      if Dir[File.join(dest_dir, '*.tif')].count { |file| File.file?(file) } == 0
         Rails.logger.error("Finish directory #{dest_dir} has no images")
         step_failed(project, "<p>Finish directory #{dest_dir} does not contain any image files</p>")
         return false
      end

      # Directory is present and has images; make sure content is all OK
      return validate_directory_content(project, dest_dir)
   end

   private
   # NOTES ON Output Folder and file moves:
   # The contents of the Output folder need to be moved to a new folder in
   # 40_first_QA/(unit subfolder). The processing of images and generating of
   # .tifs will also create a subfolder entitled CaptureOne in the Output folder.
   # This folder and its contents need to be deleted. If the entire Output folder is renamed
   # to its associated unit number and moved to 40_first_QA, then the system needs to create another
   # Output folder in 10_raw/(unit subfolder). That way if the student needs to reprocess images on
   # the server, the default location is still available to process and save the .tifs. All other
   # contents of the unit subfolder in 10_raw/(unit subfolder) should remain where they are in 10_raw.
   def move_files( project )
      # No move needed; just validate directory
      if self.start_dir == self.finish_dir
         Rails.logger.info("No automatic move needed. Validating #{self.finish_dir}...")
         return validate_finish_dir( project )
      end

      unit_dir = "%09d" % project.unit.id
      src_dir =  File.join("#{PRODUCTION_MOUNT}", self.start_dir, unit_dir)
      dest_dir =  File.join("#{PRODUCTION_MOUNT}", self.finish_dir, unit_dir)
      Rails.logger.info("Moving working files from #{src_dir} to #{dest_dir}")

      # Neither directory exists; nothing can be done; fail
      if !Dir.exists?(src_dir) && !Dir.exists?(dest_dir)
         Rails.logger.error("Manually moved destination dir #{dest_dir} does not exist")
         step_failed(project, "<p>Neither start nor finsh directory exists</p>")
         return false
      end

      # Source is gone, but dest exists and has files. Validate them
      if !Dir.exists?(src_dir) && Dir.exists?(dest_dir) && Dir[File.join(dest_dir, '*.tif')].count { |file| File.file?(file) } > 0
         Rails.logger.info("Destination directory #{src_dir} exists, and is populated. Validating...")
         return validate_finish_dir(project)
      end

      # See if there is an 'Output' directory for special handling
      output_dir =  File.join(src_dir, "Output")

      # If Output exists, treat it as the source directory - Its contents
      # will be moved into dest dir and then it will be removed, leaving
      # the root source folder intact. See notes at top of this call for details.
      begin
         if Dir.exists? output_dir
            Rails.logger.info("Output directory found. Moving it to final directory.")
            src_dir = output_dir

            # remove CaptureOne if it exists
            cap_dir =  File.join(src_dir, "CaptureOne")
            if Dir.exists? cap_dir
               Rails.logger.info("Removing CaptureOne directory from Output")
               FileUtils.rm_r cap_dir
            end
         end

         # Move the source directly to destination directory
         FileUtils.mv(src_dir, dest_dir)

         # put back the original src/Ouput folder in case student needs to recreate scans later
         if Dir.exists? output_dir
            FileUtils.mkdir src_dir
            File.chmod(0775, src_dir)
         end

         # One last validation of final directory contents, then done
         return validate_finish_dir(project)
      rescue Exception => e
         Rails.logger.error("Move files FAILED #{e.to_s}")
         # Any problems moving files around will set the assignment as ERROR and leave it
         # uncompleted. A note detailing the error will be generated. At this point, the current
         # user can try again, or manually fix the directories and finish the step again.
         note = "<p>An error occurred moving files after step completion. Not all files have been moved. "
         note << "Please check and manually move each file. When the problem has been resolved, click finish again.</p>"
         note << "<p><b>Error details:</b> #{e.to_s}</p>"
         step_failed(project, note)
         return false
      end
   end
end
