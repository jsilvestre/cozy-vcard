# Small module to generate vcard file from JS Objects or to parse vcard file
# to obtain explicit JS Objects.


# inspired by https://github.com/mattt/vcard.js

regexps =
        begin:       /^BEGIN:VCARD$/i
        end:         /^END:VCARD$/i
        simple:      /^(version|fn|title|org|note)\:(.+)$/i
        android:     /^x-android-custom\:(.+)$/i
        composedkey: /^item(\d{1,2})\.([^\:]+):(.+)$/
        complex:     /^([^\:\;]+);([^\:]+)\:(.+)$/
        property:    /^(.+)=(.+)$/

ANDROID_RELATION_TYPES = ['custom', 'assistant', 'brother', 'child',
            'domestic partner', 'father', 'friend', 'manager', 'mother',
            'parent', 'partner', 'referred by', 'relative', 'sister', 'spouse']

module.exports = class VCardParser

    reset: ->
        @contacts         = []
        @currentContact   = null
        @currentDatapoint = null
        @currentIndex     = null
        @currentVersion   = "3.0"

    read: (vcf) ->
        @reset()
        @handleLine line for line in vcf.split /\r?\n/

    handleLine: (line) ->
        if regexps.begin.test line
            @currentContact = {datapoints:[]}

        else if regexps.end.test line
            @storeCurrentDatapoint()
            @contacts.push @currentContact

        else if regexps.simple.test line
            @handleSimpleLine line

        else if regexps.android.test line
            @handleAndroidLine line

        else if regexps.composedkey.test line
            @handleComposedLine line

        else if regexps.complex.test line
            @handleComplexLine line


    storeCurrentDatapoint: () ->
        if @currentDatapoint
            @currentContact.datapoints.push @currentDatapoint
            @currentDatapoint = null

    addDatapoint: (name, type, value) ->
        @storeCurrentDatapoint()
        @currentContact.datapoints.push {name, type, value}

    # handle easy lines such as TITLE:XXX
    handleSimpleLine: (line) ->
        [all, key, value] = line.match regexps.simple

        if key is 'VERSION'
            return @currentversion = value

        if key in ['TITLE', 'ORG', 'FN', 'NOTE', 'N', 'BDAY']
            return @currentContact[key] = value

    # handle android-android lines (cursor.item)
    #@TODO support other possible cursors
    handleAndroidLine: (line) ->
        [all, raw] = line.match regexps.android
        parts = raw.split ';'
        switch parts[0].replace 'vnd.android.cursor.item/', ''
            when 'contact_event'
                value = parts[1]
                type = if parts[2] in ['0', '2'] then parts[3]
                else if parts[2] is '1' then 'anniversary'
                else 'birthday'
                @currentContact.datapoints.push
                    name: 'about', type: type, value: value
            when 'relation'
                value = parts[1]
                type = ANDROID_RELATION_TYPES[+parts[2]]
                type = parts[3] if type is 'custom'
                @currentContact.datapoints.push
                    name: 'other', type: type, value: value

    # handle multi-lines DP (custom label)
    handleComposedLine: (line) ->
        [all, itemidx, part, value] = line.match regexps.composedkey

        if @currentIndex is null or @currentIndex isnt itemidx
            @storeCurrentDatapoint()
            @currentDatapoint = {}

        @currentIndex = itemidx

        part = part.split ';'
        key = part[0]
        properties = part.splice 1

        value = value.split(';')
        value = value[0] if value.length is 1

        key = key.toLowerCase()

        if key is 'x-ablabel' or key is 'x-abadr'
            value = value.replace '_$!<', ''
            value = value.replace '>!$_', ''
            @currentDatapoint['type'] = value.toLowerCase()
        else
            @handleProperties @currentDatapoint, properties

            if key is 'adr'
                value = value.join("\n").replace /\n+/g, "\n"

            if key is 'x-abdate'
                key = 'about'

            if key is 'x-abrelatednames'
                key = 'other'

            @currentDatapoint['name'] = key.toLowerCase()
            @currentDatapoint['value'] = value.replace "\\:", ":"

    handleComplexLine: (line) ->
        [all, key, properties, value] = line.match regexps.complex

        @storeCurrentDatapoint()
        @currentDatapoint = {}

        value = value.split(';')
        value = value[0] if value.length is 1

        key = key.toLowerCase()

        if key in ['email', 'tel', 'adr', 'url']
            @currentDatapoint['name'] = key
            # value = value.join("\n").replace /\n+/g, "\n"
        else
            #@TODO handle unkwnown keys
            return

        @handleProperties @currentDatapoint, properties.split ';'

        @currentDatapoint.value = value

    handleProperties : (dp, properties) ->
        for property in properties

            # property is XXX=YYYY
            if match = property.match regexps.property
                [all, pname, pvalue] = match

            else if property is 'PREF'
                pname = 'pref'
                pvalue = true

            else
                pname = 'type'
                pvalue = property

            dp[pname] = pvalue