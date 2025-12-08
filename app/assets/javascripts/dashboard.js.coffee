# application.js.coffee
# Behaviors and hooks for matching controller
# All logic automatically available in application.js
# CoffeeScript docs: http://coffeescript.org/

ready = ->

  # -------------------------------
  # DataTables initialization
  # -------------------------------
  initDataTable = (selector, order_col=0, order_dir='asc', page_length=10) ->
    return unless $('.' + selector).length > 0
    unless $.fn.dataTable.isDataTable('.' + selector)
      dt = $('.' + selector).DataTable
        sPaginationType: 'full_numbers'
        bJQueryUI: true
        order: [[order_col, order_dir]]
        lengthMenu: [[10, 25, 50, -1], [10, 25, 50, "All"]]
        pageLength: page_length
        pagingType: 'simple_numbers'
        dom: '<"top"lf>rt<"bottom"ip><"clear">'
      return dt

  $report = initDataTable('reports', 0, 'asc', 0)
  if $report?
    $report.settings()[0].oFeatures.bPaginate = false
    $report.settings()[0].oFeatures.bFilter = false
    new $.fn.dataTable.FixedHeader($report, {bottom: true})

  initDataTable('inventory', 0, 'desc', 25)
  initDataTable('receipt', 0, 'asc', 10)

  # -------------------------------
  # Uppercase text input (delegated)
  # -------------------------------
  $(document).on 'keyup', 'input:not(.decimal-field)', (e) ->
    this.value = this.value.toUpperCase()

  # -------------------------------
  # Datepicker
  # -------------------------------
  if window.location.pathname.match(/.*generate.*bill.*/)
    $('.bill_date').datepicker dateFormat: "dd/mm/yy"

  if window.location.pathname.match(/.*receipt.*(new|edit).*/)
    $('.receipt_date_issued').datepicker dateFormat: "dd/mm/yy"

    # -------------------------------
    # Cocoon nested form: before-insert
    # -------------------------------
    $('.new_receipt').on 'cocoon:before-insert', (e, detail) ->

      $detail = $(detail)

      # Quantity input focusin: fetch stock
      $detail.find('div.qty input').on 'focusin', ->
        item_id = $(this).closest('tr').find('input.hidden-item-id').val()
        $.ajax
          url: '/items/' + item_id + '/getStock'
          success: (result) -> $(this).val(result)

      # Quantity and unit_price focusout: calculate total
      $detail.find('div.qty input, div.price input').on 'focusout', ->
        $row = $(this).closest('tr')
        qty = parseFloat($row.find('div.qty input').val()) || 0
        unit_price = parseFloat($row.find('div.price input').val()) || 0
        $row.find('div.total input').val((qty * unit_price).toFixed(2))
        $('.new_receipt div.receipt-total input').trigger('change')

      # Uppercase inputs in newly inserted row
      $detail.find('input:not(.decimal-field)').on 'keyup', (e) ->
        this.value = this.value.toUpperCase()

      # Typeahead: description
      $.getJSON '/items/descriptions', (data) ->
        $detail.find('div.description input').typeahead
          placeholder: $detail.find('div.description input').attr('placeholder')
          displayKey: 'value'
          highlight: true
          hint: true
          source: data
          allowNew: true
          items: 25

      # Typeahead: part_number on focus
      $detail.find('div.part-number input').on 'focusin', ->
        description = $(this).closest('tr').find('div.description input').val()
        $.getJSON '/items/part_numbers', {description: description}, (data) ->
          $(this).typeahead
            placeholder: $(this).attr('placeholder')
            displayKey: 'value'
            highlight: true
            hint: true
            source: data
            allowNew: true
            items: 25

      # Typeahead: inventory item select
      $.getJSON '/items/ajaxList', (data) ->
        $detail.find('.select-inventory-item').typeahead
          placeholder: $detail.find('.select-inventory-item').attr('placeholder')
          displayKey: 'value'
          highlight: true
          hint: true
          source: data
          items: 25
          allowNew: false
          updater: (item) ->
            el_item = this.$element.parent().find('.hidden-item-id')[0]
            el_item.value = item.split('|')[1]
            $.ajax
              url: '/items/' + item.split('|')[1] + '/getUnitPrice'
              success: (result) ->
                $detail.find('span.unit-price').text(result.unit_price)
            item.split('|')[0]

  # -------------------------------
  # Update total on qty/price change
  # -------------------------------
  $(document).on 'change', '.new_receipt .nested-fields div.qty input, .new_receipt .nested-fields div.price input', ->
    $row = $(this).closest('tr')
    qty = parseFloat($row.find('div.qty input').val()) || 0
    unit_price = parseFloat($row.find('div.price input').val()) || 0
    $row.find('div.total input').val((qty * unit_price).toFixed(2))
    $('.new_receipt div.receipt-total input').trigger('change')

  # -------------------------------
  # Calculate receipt total
  # -------------------------------
  $(document).on 'change', '.new_receipt div.receipt-total input', ->
    total = 0
    $('.new_receipt .receipt-detail table').each (i, table) ->
      total += parseFloat($(table).find('div.total input').val()) || 0
    $(this).val(total.toFixed(2))
    $('.new_receipt div.receipt-amount-received input').trigger('focusout')

  # -------------------------------
  # Calculate balance
  # -------------------------------
  $(document).on 'focusout', '.new_receipt div.receipt-amount-received input', ->
    total = parseFloat($('.new_receipt div.receipt-total input').val()) || 0
    received = parseFloat(this.value) || 0
    $('.new_receipt div.receipt-balance input').val((total - received).toFixed(2))

  # -------------------------------
  # Cocoon remove: reset total
  # -------------------------------
  $('.new_receipt').on 'cocoon:before-remove', (e, detail) ->
    $(detail).find('div.total input').val(0)
    $('.new_receipt div.receipt-total input').trigger('change')

  # -------------------------------
  # Report form elements
  # -------------------------------
  $('.date-month, .date-year, .date-quarter, .report-period').addClass('hide').hide()

  $('.report-type select').on 'change', ->
    $('.date-month, .date-quarter').addClass('hide').hide()
    $('.report-period, .date-year').addClass('hide').hide()
    $('.report-period select').prop('selectedIndex', 0)
    val = $(this).val()
    if val != 'Stocks'
      $('.date-month, .report-period').removeClass('hide').show()

  $('.report-period').on 'change', ->
    $('.date-month, .date-quarter').addClass('hide').hide()
    $('.date-year').removeClass('hide').show()
    period = $(this).find('select').val()
    if period == 'Monthly'
      $('.date-month').removeClass('hide').show()
      $('.date-year').addClass('hide').hide()
    else if period == 'Quarterly'
      $('.date-quarter').removeClass('hide').show()

  # -------------------------------
  # Merge items
  # -------------------------------
  $('#item_merge').on 'click', ->
    items = []
    $('input#merge:checked').each (i, el) ->
      items.push(el.value)
    window.location = "/items/merging?items=" + items

# -------------------------------
# Document ready / Turbolinks support
# -------------------------------
$(document).ready(ready)
$(document).on 'page:change', ready
$(document).on 'page:fetch', -> $('main').fadeOut 'slow'
$(document).on 'page:restore', -> $('main').fadeIn 'slow'
