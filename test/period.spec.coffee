test = (moment, Period) ->
  moment.locale 'en'

  describe "Period", ->

    defaultFormat = 'DD/MM/YYYY'

    String.prototype.toMoment = (format=defaultFormat)->
      moment(@, format)

    String.prototype.toDate = (format=defaultFormat)->
      @toMoment(format).toDate()

    it "should be defined", ->
      chai.expect(Period).to.exist

    it "use a custom date", ->
      settings =
        reference            : new Date()
        startOfFinancialYear : 7

      period = '04/03/2015'.toMoment().period('03/04/2015'.toDate(), settings)
      chai.expect(period.toString()).to.equal 'CUSTOM'

    describe "constructor", ->

      it "accepts no parameters", ->
        period = moment().period()
        chai.expect(period).to.exist
        chai.expect(period.toString()).to.equal 'CUSTOM'
        chai.expect(period.settings.base).to.equal 12
        chai.expect(period.settings.startOfFinancialYear).to.equal 1

      it "accepts a string", ->
        period = moment.period('CURRENT_MONTH')
        chai.expect(period).to.exist

        moments = period.toMoments()
        chai.expect(moments[0].format('MM')).to.equal moment().format('MM')
        chai.expect(moments[1].format('MM')).to.equal moment().format('MM')

      it "accepts Date instances", ->
        startOfMonth = moment().startOf('month').toDate()
        endOfMonth   = moment().endOf('month').toDate()
        period = moment(startOfMonth).period(endOfMonth)
        chai.expect(period.toString()).to.equal 'CURRENT_MONTH'

      it "accepts Moment instances", ->
        startOfMonth = moment().startOf('month')
        endOfMonth   = moment().endOf('month')
        period = moment(startOfMonth).period(endOfMonth)
        chai.expect(period.toString()).to.equal 'CURRENT_MONTH'

      describe "throws exception", ->

        it "when given a string as end date", ->
          throwError = ->
            period = moment().period('CURRENT_MONTH')

          chai.expect(throwError).to.throw(Error, "Wrong parameters")

        it "when invalid moment provided", ->
          throwError = ->
            period = moment().period('123123')

          chai.expect(throwError).to.throw(Error, "Wrong parameters")

        it "on invalid label", ->
          throwError = ->
            period = moment.period('LNENFNLEL')

          chai.expect(throwError).to.throw(Error, "Invalid period label")

    describe 'settings', ->

      it "can be overwritten", ->
        period = moment().period({startOfFinancialYear: 3})
        chai.expect(period.settings.startOfFinancialYear).to.equal 3

      it "are considered in dates computation", ->
        period = moment.period('CURRENT_MONTH', reference:'02/10/2016'.toDate())
        dates  = period.toDates()
        chai.expect(dates[0].getMonth()).to.equal 9
        chai.expect(dates[0].getFullYear()).to.equal 2016

    describe "set method", ->

      it "allows update of settings", ->
        period = moment.period('CURRENT_MONTH').set( settings:
          reference: moment('02/10/2016', 'DD/MM/YYYY').toDate()
        )
        dates  = period.toDates()
        chai.expect(dates[0].getMonth()).to.equal 9
        chai.expect(dates[0].getFullYear()).to.equal 2016

      it "allows update of settings", ->
        period = moment().period().set(label: 'CURRENT_MONTH')
        dates  = period.toDates()

        startOfMonth = moment().startOf('month').toDate()
        endOfMonth   = moment().endOf('month').toDate()

        chai.expect(dates[0].getMonth()).to.equal startOfMonth.getMonth()
        chai.expect(dates[0].getFullYear()).to.equal startOfMonth.getFullYear()
        chai.expect(dates[1].getMonth()).to.equal endOfMonth.getMonth()
        chai.expect(dates[1].getFullYear()).to.equal endOfMonth.getFullYear()

      describe "throws exceptions", ->
        it "when label and dates provided", ->
          throwError = ->
            period = moment().period().set
              label: 'CURRENT_MONTH'
              dates: [new Date(), new Date()]

          chai.expect(throwError).to.throw(Error, /Invalid parameters to set/)

        it "when no params provided", ->
          throwError = ->
            period = moment().period().set()

          chai.expect(throwError).to.throw(Error, "No parameters to set")

        it "when no params provided", ->
          throwError = ->
            period = moment().period().set(settings: {reference: null})

          chai.expect(throwError).to.throw(Error, "Missing settings")

    describe "financial year", ->

      check = (args...)->
        period = moment().period(@settings)

        chai.expect( period._getCurrentFinancialYear() ).to.equal args[0]
        chai.expect( period._currentMonthIndex() ).to.equal args[1]
        chai.expect( period._getCurrentQuarterIndex() ).to.equal args[2]

        labelDates = args[3]
        for label, dateAsString of labelDates
          moments = period.set(label: label).toMoments()
          chai.expect( moments[0].format(defaultFormat) )
          .to.equal dateAsString[0]
          chai.expect( moments[1].format(defaultFormat) )
          .to.equal dateAsString[1]

          periodFromDates = moment(dateAsString[0].toDate())
                            .period(dateAsString[1].toDate(), @settings)
          chai.expect( periodFromDates.toString() ).to.equal label

      describe "starts in july", ->

        @settings =
          startOfFinancialYear: 7

        it "is the 2nd april 2015", =>
          @settings.reference = new Date(2015, 3, 2) #april

          check.call(@, 2014, 10, 4,
            CURRENT_MONTH          : ['01/04/2015','30/04/2015']
            CURRENT_FINANCIAL_YEAR : ['01/07/2014','30/06/2015']
            LAST_MONTH             : ['01/03/2015','31/03/2015']
            CURRENT_QUARTER        : ['01/04/2015','30/06/2015']
            LAST_QUARTER           : ['01/01/2015','31/03/2015']
            LAST_FINANCIAL_YEAR    : ['01/07/2013','30/06/2014']
          )

        it "is the 1st july 2015", =>
          @settings.reference = new Date(2015, 6, 1) #july

          check.call(@, 2015, 1, 1,
            CURRENT_MONTH          : ['01/07/2015','31/07/2015']
            CURRENT_FINANCIAL_YEAR : ['01/07/2015','30/06/2016']
            LAST_MONTH             : ['01/06/2015','30/06/2015']
            CURRENT_QUARTER        : ['01/07/2015','30/09/2015']
            LAST_QUARTER           : ['01/04/2015','30/06/2015']
            LAST_FINANCIAL_YEAR    : ['01/07/2014','30/06/2015']
          )

        it "is the 23rd december 2015", =>
          @settings.reference = new Date(2015, 11, 23) #december

          check.call(@, 2015, 6, 2,
            CURRENT_MONTH          : ['01/12/2015','31/12/2015']
            CURRENT_FINANCIAL_YEAR : ['01/07/2015','30/06/2016']
            LAST_MONTH             : ['01/11/2015','30/11/2015']
            CURRENT_QUARTER        : ['01/10/2015','31/12/2015']
            LAST_QUARTER           : ['01/07/2015','30/09/2015']
            LAST_FINANCIAL_YEAR    : ['01/07/2014','30/06/2015']
          )

      describe "starts in march", ->

        @settings =
          startOfFinancialYear: 3

        it "is the 1st february 2015", =>
          @settings.reference = new Date(2015, 1, 1) #february

          check.call(@, 2014, 12, 4,
            CURRENT_MONTH          : ['01/02/2015','28/02/2015']
            CURRENT_FINANCIAL_YEAR : ['01/03/2014','28/02/2015']
            LAST_MONTH             : ['01/01/2015','31/01/2015']
            CURRENT_QUARTER        : ['01/12/2014','28/02/2015']
            LAST_QUARTER           : ['01/09/2014','30/11/2014']
            LAST_FINANCIAL_YEAR    : ['01/03/2013','28/02/2014']
          )

        it "is the 10th march 2015", =>
          @settings.reference = new Date(2015, 2, 10) #march

          check.call(@, 2015, 1, 1,
            CURRENT_MONTH          : ['01/03/2015','31/03/2015']
            CURRENT_FINANCIAL_YEAR : ['01/03/2015','29/02/2016']
            LAST_MONTH             : ['01/02/2015','28/02/2015']
            CURRENT_QUARTER        : ['01/03/2015','31/05/2015']
            LAST_QUARTER           : ['01/12/2014','28/02/2015']
            LAST_FINANCIAL_YEAR    : ['01/03/2014','28/02/2015']
          )

        it "is the 1st october 2015", =>
          @settings.reference = new Date(2015, 9, 1) #october

          check.call(@, 2015, 8, 3,
            CURRENT_MONTH          : ['01/10/2015','31/10/2015']
            CURRENT_FINANCIAL_YEAR : ['01/03/2015','29/02/2016']
            LAST_MONTH             : ['01/09/2015','30/09/2015']
            CURRENT_QUARTER        : ['01/09/2015','30/11/2015']
            LAST_QUARTER           : ['01/06/2015','31/08/2015']
            LAST_FINANCIAL_YEAR    : ['01/03/2014','28/02/2015']
          )

      describe "starts in january", ->

        @settings =
          startOfFinancialYear: 1

        it "is the 1st january 2015", =>
          @settings.reference = new Date(2015, 0, 1) #january

          check.call(@, 2015, 1, 1,
            CURRENT_MONTH          : ['01/01/2015','31/01/2015']
            CURRENT_FINANCIAL_YEAR : ['01/01/2015','31/12/2015']
            LAST_MONTH             : ['01/12/2014','31/12/2014']
            CURRENT_QUARTER        : ['01/01/2015','31/03/2015']
            LAST_QUARTER           : ['01/10/2014','31/12/2014']
            LAST_FINANCIAL_YEAR    : ['01/01/2014','31/12/2014']
          )

        it "is the 4th june 2015", =>
          @settings.reference = new Date(2015, 5, 4) #june

          check.call(@, 2015, 6, 2,
            CURRENT_MONTH          : ['01/06/2015','30/06/2015']
            CURRENT_FINANCIAL_YEAR : ['01/01/2015','31/12/2015']
            LAST_MONTH             : ['01/05/2015','31/05/2015']
            CURRENT_QUARTER        : ['01/04/2015','30/06/2015']
            LAST_QUARTER           : ['01/01/2015','31/03/2015']
            LAST_FINANCIAL_YEAR    : ['01/01/2014','31/12/2014']
          )

        it "is the 15th december 2015", =>
          @settings.reference = new Date(2015, 11, 15) #december

          check.call(@, 2015, 12, 4,
            CURRENT_MONTH          : ['01/12/2015','31/12/2015']
            CURRENT_FINANCIAL_YEAR : ['01/01/2015','31/12/2015']
            LAST_MONTH             : ['01/11/2015','30/11/2015']
            CURRENT_QUARTER        : ['01/10/2015','31/12/2015']
            LAST_QUARTER           : ['01/07/2015','30/09/2015']
            LAST_FINANCIAL_YEAR    : ['01/01/2014','31/12/2014']
          )


if define?
  define(['moment', 'period'], (moment, Period) -> test moment, Period)
else
  chai   = require?('chai') ? @chai
  moment = require?('moment') ? @moment
  Period = require?('../dist/period') ? @Period
  test moment, Period
