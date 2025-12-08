# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

# Helper function to perform precise multiplication for currency.
# It converts floats to cents (x100) before multiplying to avoid floating point errors.
# Result is returned as a rounded number (in cents) which must be converted back to dollars/decimal.
calculatePreciseTotal = (qty, unit_price) ->
  # Convert inputs to numbers first, handle potential nulls/empties with 0
  qty = parseFloat(qty) || 0
  unit_price = parseFloat(unit_price) || 0

  # Convert to cents, multiply, and round the result to the nearest cent
  # We use Math.round(x * 100) to ensure the conversion to cents is accurate
  qty_cents = Math.round(qty * 100)
  price_cents = Math.round(unit_price * 100)

  # Perform the multiplication in cents, then divide by 100 to get the result in cents.
  # Example: 1.5 * 2.0 = 3.00. (150 * 200) / 100 = 300 (cents)
  # NOTE: The division by 100 is key because we multiplied both factors by 100.
  # We round the final result (in cents) to prevent intermediate floating point issues.
  total_cents = Math.round((qty_cents * price_cents) / 100)

  # Return the value as a string formatted to two decimal places
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
    ### datepicker - add/update receipt form ###
    $('.receipt_date_issued').datepicker(
      dateFormat: "dd/mm/yy"
    )

    # Function to calculate and update a single receipt detail row total
    updateRowTotal = ($row) ->
      # Get current Qty and Unit Price values
      qty = $row.find('div.qty input')[0].value
      unit_price = $row.find('div.price input')[0].value
      $total = $row.find('div.total input')[0]

      # Use the precise helper function
      $total.value = calculatePreciseTotal(qty, unit_price)
      
      # Trigger overall receipt total update
      $('.new_receipt div.receipt-total input').trigger('change')
      return

    ### cocoon nested forms ###
    $('.new_receipt').on('cocoon:before-insert', (e, detail) ->
      ### calculate receipt_detail total ###
      $qty_input = $(detail.find('div.qty input'))
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
                $row.find('div.price input').val(result.unit_price).trigger('focusout') # Trigger the updateRowTotal
                $(detail.find('span.unit-price')).text(result.unit_price)
            })

            return item.split('|')[0]
          allowNew: false
        return
      return
    )

    # Note: These change events now call the central updateRowTotal function
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


    ### calculate receipt total - REVISED for precision ###
    $('.new_receipt div.receipt-total input').on('change', ->
      receipt_details = $('.new_receipt .receipt-detail table')
      len = receipt_details.length
      index = 0
      # Accumulate total in CENTS to maintain precision
      total_amount_cents = 0

      while index < len
        # Get the value from the total input (which is already fixed to 2 decimals as a string)
        row_total_value = $(receipt_details[index]).find('div.total input')[0].value
        # Convert to cents and add to the running total
        total_amount_cents += Math.round(parseFloat(row_total_value) * 100)
        ++index

      # Convert the final total cents back to a decimal string
      this.value = (total_amount_cents / 100).toFixed(2)
      $('.new_receipt div.receipt-amount-received input').trigger('focusout')
      return
    )

    ### calculate balance - REVISED for precision ###
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
    $total_input = $(detail.find('div.total input'))
    $total_input.val(0)
    $('.new_receipt div.receipt-total input').trigger('change')
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
    console.log('TODO ' + items)
    window.location = "/items/merging?items=" + items
  )
  ### merge item end ###

  return

$(document).ready(ready)
$(document).on('page:change', ready)
$(document).on 'page:fetch', ->
  $('main').fadeOut 'slow'

$(document).on 'page:restore', ->
  $('main').fadeIn 'slow'