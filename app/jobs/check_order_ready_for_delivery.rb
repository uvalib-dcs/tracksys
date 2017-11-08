class CheckOrderReadyForDelivery < BaseJob
   include BuildOrderPDF
   
   def set_originator(message)
      @status.update_attributes( :originator_type=>"Order", :originator_id=>message[:order_id] )
   end

   # This processor only accepts units whose delivery_mode = 'patron', so there is no need to worry, from here on out, about 'dl' materials.
   def do_workflow(message)
      raise "Parameter 'order_id' is required" if message[:order_id].blank?
      order = Order.find(message[:order_id])
      incomplete_units = []

      logger.info "Checking units for completeness..."
      order.units.each do |unit|
         # If an order can have both patron and dl-only units (i.e. some units have an intended use of "Digital Collection Building")
         # then we have to remove from consideration those units whose intended use is "Digital Collection Building"
         # and consider all other units.
         logger.info "   Check unit #{unit.id}"
         if  unit.intended_use.description != "Digital Collection Building"
            if unit.unit_status != "canceled"
               if unit.date_patron_deliverables_ready.nil?
                  logger.info "   Unit #{unit.id} incomplete"
                  incomplete_units.push(unit.id)
               else
                  logger.info "   Unit #{unit.id} COMPLETE"
               end
            else
               logger.info "   unit is canceled"
            end
         else
            logger.info "   unit is for digital collection building"
         end
      end
      logger.info "Incomplete units count #{incomplete_units.count}"

      # If any units are not comlete, the order is incomplete
      if !incomplete_units.empty?
         logger.info("Order #{message[:order_id]} is incomplete with units #{incomplete_units.join(", ")} still unfinished")
         return
      end

      # Nothign more to do if customer was already notified...
      if order.date_customer_notified
         on_failure("The date_customer_notified field on order #{message[:order_id]} is filled out.  The order appears to have been delivered already.")
         return
      end

      # The 'patron' units within the order are complete, and customer not yet notified
      # Flag deliverable complete data and begin order QA process that will result
      # in a PDF ad patron email being generated if all is goos
      on_success("All units in order #{message[:order_id]} are complete and will now begin the delivery process.")
      order.update_attribute(:date_patron_deliverables_complete, Time.now)

      # Failed QA checks will terminiate the job immediately
      qa_order_fees(order)

      # QA was successful, generate PDF and email
      create_pdf(order)
      CreateOrderEmail.exec_now({:order => order}, self)
   end

   private
   def create_pdf
      logger.info("Create order PDF...")
      pdf = generate_invoice_pdf(order)
      order_dir = File.join("#{DELIVERY_DIR}", "order_#{order.id}")
      Dir.mkdir(order_dir) unless File.exists?(order_dir)
      invoice_file = File.join(order_dir, "#{order.id}.pdf")
      pdf.render_file(invoice_file  )
      logger.info "PDF created for order #{order.id} created at #{invoice_file}"
   end

   private
   def qa_order_fees(order)
      logger.info "QA order #{order.id} status and fees..."

      # At this point, the order status must be 'approved'.
      if order.order_status != 'approved'
         on_error "Order #{order.id} does not have an order status of 'approved'.  Please correct before proceeding."
      end

      # An order whose customer is non-UVA and whose actual fee is blank is invalid.
      if order.customer.academic_status_id == 1 && order.fee_actual.nil?
         on_error "Order #{order.id} has a non-UVA customer and the 'Actual Fee' is blank.  Please fill in with a value."
      end

      # If there is a value for fee_estimated then there must be a value in fee_actual
      if order.fee_estimated && order.fee_actual.blank?
         on_error "Error with order fee: Order #{order.id} has an estimated fee but no actual fee."
      elsif order.fee_actual && order.fee_estimated.blank?
         on_error "Error with order fee: Check if customer approved fees because the estimated fee is blank while the actual fee is not."
      elsif order.fee_estimated && order.fee_actual
         if order.fee_estimated.to_i == 0 && order.fee_actual.to_i != 0
            on_error "Error with order fee: Fee estimated is equal to 0.00 but the fee actual is greater than that.  Check customer correspondence and update information."
         elsif order.fee_estimated.to_i == 0 && order.fee_actual.to_i == 0
            logger.info "Order fee checked. #{order.id} has no fees associated with it."
         else
            fee = order.fee_actual
            logger.info "Order fee checked. #{order.id} has a fee of #{fee} and both the estimated and actual fee values are greater than 0.00"
         end
      else
         logger.info "Order fee checked. #{order.id} has no fees associated with it."
      end

      logger.info "Order #{order.id} has passed QA"
   end
end
