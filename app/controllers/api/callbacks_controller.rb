class Api::CallbacksController < ApplicationController

   # callback from OCR service. Accepts results
   #
   def ocr
      job_id = params[:jid]
      job = JobStatus.find_by(id: job_id)
      render plain: "Job ID not found", status: :not_found and return if job.nil?

      job_logger = job.create_logger()
      job_logger.info "OCR processing started at #{params[:started]}"
      resp = JSON.parse(params[:json])
      if resp["status"] == "success"
         job_logger.info "OCR successfully completed at #{resp['finished']}"
         job.finished
      else 
         job_logger.fatal "OCR FAILED at #{resp['finished']}"
         job_logger.fatal "Failure details #{resp['message']}"
         job.failed( resp['message'])
      end
   end
end