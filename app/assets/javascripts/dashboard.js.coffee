# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

# Helper function to perform precise multiplication for currency.
# This prevents JavaScript floating point errors (e.g., 0.1 * 3 = 0.30000000000000004).
calculatePreciseTotal = (qty, unit_price) ->
  # Convert inputs to numbers first, handle potential nulls/empties with 0
  qty = parseFloat(qty) || 0
  unit_price = parseFloat(unit_price) || 0

  # 1. Calculate the raw product (subject to float errors)
  raw_product = qty * unit_price
  
  # 2. Convert the raw product to cents and round it to the nearest integer (cent).
  total_cents = Math.round(raw_product * 100)

  # 3. Return the value as a string formatted to two decimal places
  return (total_cents / 100).toFixed(2)

# Helper function to perform precise subtraction (a - b)
calculatePreciseDifference = (total, received) ->
  # Convert inputs to cents (integers)
  total_cents = Math.round(parseFloat(total) * 100)
  received_cents = Math.round(parseFloat(received) * 100)

  # Perform subtraction
  difference_cents = total_cents - received_cents

  # Convert back to decimal string and return
  return (difference_cents / 100).toFixed(2)


# Function to clean and enforce decimal-only input (digits and a single decimal point)
# NOW INCLUDES LIMITING TO TWO DECIMAL PLACES.
enforceDecimalInput = (e) ->
  # Get the current value
  current_value = $(this).val()
  
  # 1. Strip all non-numeric and non-dot/non-comma characters
  cleaned_value = current_value.replace(/[^0-9\.\,]/g, '')
  
  # 2. Replace comma with dot (standardizing decimal separator)
  cleaned_value = cleaned_value.replace(',', '.')
  
  # 3. Ensure only one decimal point exists
  first_dot_index = cleaned_value.indexOf('.')
  if first_dot_index != -1
    # Everything before the first dot + the first dot + everything after the first dot (excluding subsequent dots)
    cleaned_value = cleaned_value.substring(0, first_dot_index + 1) + cleaned_value.substring(first_dot_index + 1).replace(/\./g, '')

    # 4. 🛑 NEW LOGIC: Limit to exactly two decimal places 🛑
    decimal_part = cleaned_value.substring(first_dot_index + 1)
    if decimal_part.length > 2
      # Truncate the string to include the whole number part, the dot, and exactly two digits after the dot.
      # first_dot_index + 3 gives us the position right after the second decimal digit.
      cleaned_value = cleaned_value.substring(0, first_dot_index + 3) 

  # Update the input value only if it changed
  if current_value != cleaned_value
    $(this).val(cleaned_value)
  
  return


ready = ->
  if !$.fn.dataTable.isDataTable( ".inventory" )
    if $('.inventory').length > 0
      $('.inventory').DataTable
        sPaginationType: 'full_numbers'
        bJQueryUI: true
        'order': [[0, 'desc']]
        lengthMenu: [[10, 25, 50, -1], [10, 25, 50, "All"]]
        pageLength: 25
        pagingType: 'simple_numbers'
        dom: '<"top"lf>rt<"bottom"ip><"clear">'

  if !$.fn.dataTable.isDataTable( ".receipt" )
    if $('.receipt').length > 0
      $('.receipt').DataTable
        sPaginationType: 'full_numbers'
        bJQueryUI: true
        'order': [[0, 'asc']]
        lengthMenu: [[10, 25, -1], [10, 25, "All"]]
        pageLength: 10
        pagingType: 'simple_numbers'
        dom: '<"top"lf>rt<"bottom"ip><"clear">'

  if !$.fn.dataTable.isDataTable( ".reports" )
    if $('.reports').length > 0
      $report = $('.reports').DataTable
        sPaginationType: 'full_numbers'
        bJQueryUI: true
        'order': [[0, 'asc']]
        paging: false
        searching: false
      new $.fn.dataTable.FixedHeader($report, {bottom: true})

  ### user input must be uppercase ###
  $('input').on('keyup', (e) ->
    this.value = this.value.toUpperCase()
    return
  )

  if window.location.pathname.match(/.*generate.*bill.*/)
    ### datepicker - add/update generate bill form ###
    $('.bill_date').datepicker(
      dateFormat: "dd/mm/yy"
    )

  ### receipt form elements start ###
  if (window.location.pathname.match(/.*receipt.*(new|edit).*/))
    
    # Apply the input restriction to all current qty and price inputs
    $('.new_receipt .nested-fields div.qty input, .new_receipt .nested-fields div.price input').on('input', enforceDecimalInput)
    
    ### datepicker - add/update receipt form ###
    $('.receipt_date_issued').datepicker(
      dateFormat: "dd/mm/yy"
    )
    
    # CENTRALIZED FUNCTION: Calculates the sum of all row totals and updates the main receipt total.
    recalculateReceiptTotal = () ->
      # Select ALL input fields that hold the line item totals
      $row_totals = $('.new_receipt .nested-fields div.total input')
      
      total_amount_cents = 0
      
      $row_totals.each ->
        # Get the value from the total input (which is already fixed to 2 decimals as a string)
        row_total_value = this.value
        # Convert to cents and add to the running total
        total_amount_cents += Math.round(parseFloat(row_total_value) * 100)
        return

      # Convert the final total cents back to a decimal string
      final_total = (total_amount_cents / 100).toFixed(2)
      
      # Set the main receipt total value
      $('.new_receipt div.receipt-total input').val(final_total)
      
      # Trigger balance calculation immediately after total updates
      $('.new_receipt div.receipt-amount-received input').trigger('focusout')
      return


    # Function to calculate and update a single receipt detail row total
    updateRowTotal = ($row) ->
      # Get current Qty and Unit Price values
      qty = $row.find('div.qty input')[0].value
      unit_price = $row.find('div.price input')[0].value
      $total = $row.find('div.total input')[0]

      # Use the precise helper function
      $total.value = calculatePreciseTotal(qty, unit_price)
      
      # Trigger overall receipt total update
      recalculateReceiptTotal()
      return

    ### cocoon nested forms ###
    $('.new_receipt').on('cocoon:before-insert', (e, detail) ->
      ### calculate receipt_detail total ###
      $qty_input = $(detail.find('div.qty input'))
      $qty_input.on('input', enforceDecimalInput) # Apply input filtering
      $qty_input.on('focusin', ->
        tag_input = $($(detail).find('input.hidden-item-id')).val()
        $.ajax({
          url: '/items/'+tag_input+'/getStock',
          success: (result) ->
            $(detail.find('div.qty input')).val(result)
        })
        return
      )
      $qty_input.on('focusout', ->
        $row = $(this).parents().closest('tr')
        updateRowTotal($row) # Call the central update function
        return
      )

      $unit_price_input = $(detail.find('div.price input'))
      $unit_price_input.on('input', enforceDecimalInput) # Apply input filtering
      $unit_price_input.on('focusout', ->
        $row = $(this).parents().closest('tr')
        updateRowTotal($row) # Call the central update function
        return
      )

      ### user input must be uppercase ###
      $(detail.find('input')).each( (index, element) ->
        $(element).on('keyup', (e) ->
          this.value = this.value.toUpperCase()
          return
        )
      )

      ### typeahead js ###
      $.getJSON '/items/descriptions', (data) ->
        tag_input = $(detail.find('div.description input'))
        tag_input.typeahead
          placeholder: tag_input.attr('placeholder')
          displayKey: 'value'
          highlight: true
          hint: true
          source: data
          allowNew: true
          items: 25
        return

      $part_number = $(detail.find('div.part-number input'))
      $part_number.on('focusin', ->
        ### typeahead js ###
        description = $(detail.find('div.description input')).val()
        $.getJSON '/items/part_numbers', {description:description}, (data) ->
          $part_number.typeahead
            placeholder: $part_number.attr('placeholder')
            displayKey: 'value'
            highlight: true
            hint: true
            source: data
            allowNew: true
            items: 25
          return
        return
      )

      ### typeahead js ###
      $.getJSON '/items/ajaxList', (data) ->
        tag_input = $(detail.find('.select-inventory-item'))
        tag_input.typeahead
          placeholder: tag_input.attr('placeholder')
          displayKey: 'value'
          highlight: true
          hint: true
          source: data
          items: 25
          updater: (item) ->
            el_item = this.$element.parent().find('.hidden-item-id')[0]
            el_item.value = item.split('|')[1]

            $.ajax({
              url: '/items/'+item.split('|')[1]+'/getUnitPrice',
              success: (result) ->
                # Update price input and trigger recalculation
                $row = tag_input.parents().closest('tr')
                $row.find('div.price input').val(result.unit_price) # Don't trigger focusout here to avoid double-calculation
                updateRowTotal($row)
                $(detail.find('span.unit-price')).text(result.unit_price)
            })

            return item.split('|')[0]
          allowNew: false
        return
      return
    )

    # Note: These change/focusout events now call the central updateRowTotal function
    $('.new_receipt .nested-fields div.qty input').on('change', (e, detail) ->
      $row = $(this).parents().closest('tr')
      updateRowTotal($row)
      return
    )

    $('.new_receipt .nested-fields div.price input').on('change', (e, detail) ->
      $row = $(this).parents().closest('tr')
      updateRowTotal($row)
      return
    )


    ### calculate receipt total - Now just calls the centralized function ###
    # We trigger the recalculation when the total input changes (which is driven by updateRowTotal)
    $('.new_receipt div.receipt-total input').on('change', recalculateReceiptTotal)

    ### calculate balance - REVISED for precision ###
    # This also recalculates the total first if triggered by focusout
    $('.new_receipt div.receipt-amount-received input').on('focusout', ->
      balance = $('.new_receipt div.receipt-balance input')[0]
      total = $('.new_receipt div.receipt-total input')[0].value # String value of Total
      received = this.value # String value of Amount Received

      # Use the precise helper function for subtraction
      balance.value = calculatePreciseDifference(total, received)
      
      return
    )

    ### typeahead js ###
    $.getJSON '/items/descriptions', (data) ->
      tag_input = $('.new_receipt .nested-fields div.description input')
      tag_input.typeahead
        placeholder: tag_input.attr('placeholder')
        displayKey: 'value'
        highlight: true
        hint: true
        source: data
        allowNew: true
        items: 25
      return

    $part_number = $('.new_receipt .nested-fields div.part-number input')
    $part_number.on('focusin', ->
      ### typeahead js ###
      description = $('.new_receipt .nested-fields div.description input').val()
      $.getJSON '/items/part_numbers', {description:description}, (data) ->
        $part_number.typeahead
          placeholder: $part_number.attr('placeholder')
          displayKey: 'value'
          highlight: true
          hint: true
          source: data
          allowNew: true
          items: 25
        return
      return
    )

    ### typeahead js ###
    $.getJSON '/items/ajaxList', (data) ->
      tag_input = $('.new_receipt .nested-fields .select-inventory-item')
      tag_input.typeahead
        placeholder: tag_input.attr('placeholder')
        displayKey: 'value'
        highlight: true
        hint: true
        items: 25
        source: data
        updater: (item) ->
          el_item = this.$element.parent().find('.hidden-item-id')[0]
          el_item.value = item.split(' - ')[2]
          return item
        allowNew: false
      return

  $('.new_receipt').on('cocoon:before-remove', (e, detail) ->
    # Set the total of the row being removed to zero BEFORE recalculating the main total
    $total_input = $(detail.find('div.total input'))
    $total_input.val(0)
    
    # Recalculate the receipt total immediately
    recalculateReceiptTotal()
    return
  )
  ### receipt form elements end ###

  ### report form elements start ###
  $('.date-month').addClass('hide').hide()
  $('.date-year').addClass('hide').hide()
  $('.report-period').addClass('hide').hide()
  $('.report-type select').on('change', ->
    # reset options
    $('.date-month').removeClass('hide').show()
    $('.date-year').addClass('hide').hide()
    $('.date-quarter').addClass('hide').hide()
    $('.report-period').removeClass('hide').show()
    $('.report-period select').prop('selectedIndex', 0)

    if ($(this).val() == 'Stocks')
      $('.date-month').addClass('hide').hide()
      $('.report-period').addClass('hide').hide()
  )

  $('.report-period').on('change', ->
    # reset options
    $('.date-month').addClass('hide').hide()
    $('.date-quarter').addClass('hide').hide()
    $('.date-year').removeClass('hide').show()

    if ($(this).find('select').val()=='Monthly')
      $('.date-month').removeClass('hide').show()
      $('.date-year').addClass('hide').hide()
    else if ($(this).find('select').val()=='Quarterly')
      $('.date-quarter').removeClass('hide').show()
  )
  ### report form elements end ###

  ### merge item start ###
  $('#item_merge').on('click', ->
    items = []
    $('input#merge:checked').each( (index)->
      items.push(this.value)
    )
    console.log('TODO ' + items);
    window.location = "/items/merging?items=" + items;
  )
  ### merge item end ###

  return

$(document).ready(ready)
$(document).on('page:change', ready)
$(document).on 'page:fetch', ->
  $('main').fadeOut 'slow'

$(document).on 'page:restore', ->
  $('main').fadeIn 'slow'