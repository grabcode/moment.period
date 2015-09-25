hasModule = module? && module.exports?

_ =
  extend: (first, others...) ->
    for other in others
      for attr of other
        first[attr] = other[attr] unless typeof other[attr] == 'undefined'
    first
  isArray: (input) ->
    Object.prototype.toString.call(input) == '[object Array]'

factory = (moment) ->
  throw new Error("Can't find moment") unless moment?

  class Period

    labels:
      'TODAY'                  : 'Today'
      'CURRENT_MONTH'          : 'This Month'
      'CURRENT_QUARTER'        : 'This Quarter'
      'CURRENT_FINANCIAL_YEAR' : 'This Financial Year'
      'LAST_MONTH'             : 'Last Month'
      'LAST_QUARTER'           : 'Last Quarter'
      'LAST_FINANCIAL_YEAR'    : 'Last Financial Year'
      'CUSTOM'                 : 'Custom'

    constructor: (start, end, settings={})->
      @settings =
        base                 : 12
        reference            : new Date() #date of reference
        startOfFinancialYear : 1 #start of financial year month, index 1 (january=1)

      if typeof start is "string"
        throw new Error("Invalid period label") unless @labels[start]?
        @set
          label    : start
          settings : end
      else
        start = start.toDate() if moment.isMoment(start) and start.isValid()
        unless end?
          end = new Date()
        else if moment.isMoment(end) and end.isValid()
          end = end.toDate()
        else if !(end instanceof Date) && (end instanceof Object)
          settings = end
          end      = new Date()

        if start instanceof Date and end instanceof Date
          @set
            dates    : [start, end]
            settings : settings
        else
          throw new Error("Wrong parameters")

      @

    set: (params)->
      throw new Error("No parameters to set") unless params?

      if params.settings
        @settings = _.extend(@settings, params.settings)

      if @settings.reference? and @settings.startOfFinancialYear? and @settings.base?
        @_loadCache()
      else
        throw new Error("Missing settings")

      if params.label? and params.dates?
        throw new Error("Invalid parameters to set. Do not provide label and dates.")
      else if params.label?
        @label = params.label
        @dates   = @_getDatesFromLabel(@label)
      else if params.dates?
        @dates = params.dates
        @label = @_getLabelFromDates(@dates)
      else
        # settings updated - refresh dates
        @dates = @_getDatesFromLabel(@label)

      @

    toString: ->
      @label

    toDates: ->
      @dates

    toMoments: ->
      [moment(@dates[0]), moment(@dates[1])]

    _cache: {}

    _loadCache: ->
      for label of @labels
        dates = @_getDatesFromLabel(label)
        if dates[1]?
          @_cache[@_buildCacheKey([new Date(dates[0]), new Date(dates[1])])] = label
        else
          @_cache[ @_buildCacheKey( new Date(dates[0]) ) ] = label

    _getDatesFromLabel: (label) ->
      return undefined unless !!~@labels.hasOwnProperty(label)

      if label is 'CUSTOM'
        date = new Date()
        return [date, new Date().setFullYear(date.getFullYear() + 1)]

      startDate = new Date(@_timeToZero @settings.reference)
      endDate   = new Date(@_timeToZero @settings.reference)

      startDate.setDate(1)

      switch label
        when 'TODAY'
          startDate = @_timeToZero(new Date())
          endDate   = moment(startDate).endOf('d').toDate()

        when 'CURRENT_MONTH'
          endDate = moment(endDate).endOf('month').toDate()

        when 'LAST_MONTH'
          lastMonth = (endDate.getMonth()-1)%12
          startDate.setMonth(lastMonth)
          endDate = moment( endDate.setMonth(lastMonth) ).endOf('month').toDate()

        when 'CURRENT_FINANCIAL_YEAR'
          startDate.setFullYear @_getCurrentFinancialYear()
          startDate.setMonth @settings.startOfFinancialYear - 1
          endDate = moment(startDate).add(1, 'years').add(-1, 'days').endOf('day').toDate()

        when 'LAST_FINANCIAL_YEAR'
          startDate.setFullYear( @_getCurrentFinancialYear() - 1 )
          startDate.setMonth @settings.startOfFinancialYear - 1
          endDate = moment(startDate).add(1, 'years').add(-1, 'days').endOf('day').toDate()

        when 'CURRENT_QUARTER'
          return @_getQuarterDates( @_getCurrentQuarterIndex(), startDate, endDate )

        when 'LAST_QUARTER'
          return @_getQuarterDates( @_getCurrentQuarterIndex() - 1, startDate, endDate )

      [startDate, endDate]

    _getLabelFromDates: (dates)->
      @_cache[ @_buildCacheKey(dates) ] || 'CUSTOM'

    _getLabelFromDate: (date)->
      @_cache[ @_buildCacheKey(date) ] || 'CUSTOM'

    _getDateFromLabel: (label) ->
      return undefined unless !!~@labels.hasOwnProperty(label)

      return new Date() if label is 'custom'

      date = new Date(@_timeToZero @settings.reference)
      #start defining semantics
      date.setDate(1) if label.indexOf('firstOf') is 0

      switch label
        when 'firstOfNextMonth'
          nextMonth = (date.getMonth()+1)%12
          date.setMonth(nextMonth)
        when 'firstOfFinancialYear'
          date.setMonth(@settings.startOfFinancialYear)

      date

    _buildCacheKey: (param)->
      if _.isArray(param)
        param[0].getTime() + '-' + moment(param[1]).endOf('day').toDate().getTime()
      else
        param.getTime()

    _timeToZero: (date)->
      date.setSeconds(0)
      date.setMinutes(0)
      date.setHours(0)
      new Date(parseInt(date.getTime()/1000)*1000)

    _getCurrentFinancialYear: ->
      #month, index 0
      currentFinancialYear = @settings.reference.getFullYear()
      currentMonth         = @settings.reference.getMonth()
      financialYearMonth   = @settings.startOfFinancialYear - 1

      if currentMonth < financialYearMonth
        currentFinancialYear -= 1

      currentFinancialYear

    # quarter index point of reference is the start date of the financial year
    # examples:
    #   index= -1 means last quarter of previous financial year
    #   index= 5 means first quarter of next financial year
    _getQuarterDates: (index, startDate, endDate)->
      year = @_getCurrentFinancialYear()

      #init financial year start date
      startDate.setFullYear year
      startDate.setMonth @settings.startOfFinancialYear - 1

      startDate = moment(startDate).add( (index-1)*3 , 'months')
      endDate   = moment(startDate).add(3, 'months').add(-1, 'days').endOf('day')

      [startDate.toDate(), endDate.toDate()]

    # n-th months of current financial year
    # examples:
    #   october is the 4th month of the finanicial year starting in july
    #   february is the 12th month of the finanicial year starting in march
    _currentMonthIndex: ->
      currentMonth       = @settings.reference.getMonth()
      financialYearMonth = @settings.startOfFinancialYear - 1
      ((currentMonth-financialYearMonth+@settings.base) % @settings.base) + 1

    _getCurrentQuarterIndex: ->
      currentMonthIdx = @_currentMonthIndex()
      Math.ceil(currentMonthIdx/(@settings.base/4)) #quarter = 1/4 from base

    _getCurrentSemesterIndex: ->
      currentMonthIdx = @_currentMonthIndex()
      Math.ceil(currentMonthIdx/(@settings.base/6)) #semester = 1/6 from base

  moment.period = -> new Period(arguments...)
  moment.period.isPeriod = (input)->
    input instanceof Period
  moment.fn.period = -> new Period(this, arguments...)

  Period


# -- MAKE AVAILABLE
return module.exports = factory(require 'moment') if hasModule

if  typeof(define) == 'function'
  define 'period', ['moment'], (moment) -> factory(moment)

if @moment
  @Period = factory(@moment)
else if moment?
  # Also checks globals (Meteor)
  @Period = factory(moment)
