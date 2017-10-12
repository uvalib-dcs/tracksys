class Api::ReportsController < ApplicationController

   # Generate the JSON data used to drive a report
   #
   def generate
      if params[:type] == "avg_time"
         render json: Report.avg_times(params[:start], params[:end]) and return
      elsif params[:type] == "problems"
         render json: Report.problems(params[:start], params[:end]) and return
      elsif params[:type] == "categories"
         render json: Report.categories() and return
      elsif params[:type] == "rejections"
         render json: Report.rejections(params[:workflow], params[:start], params[:end]) and return
      end

      render plain: "Unsupported report type", status: :error
   end
end
