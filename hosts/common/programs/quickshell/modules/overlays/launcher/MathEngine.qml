pragma Singleton

import QtQuick

QtObject {
    id: root

    /*
     * #1 ROOT STATE
     */

    property string mathResultString: ""

    /*
     * #2 REGEX
     */

    readonly property var conversionPattern:/^\s*([$€£¥₹₩₽元]?\s*[+-]?\d*\.?\d+)\s*([a-zA-Z°\/$€£¥₹₩₽元]+)(?:\s+(?:to|in)\s+([a-zA-Z°\/$€£¥₹₩₽元]+))?\s*$/i
    readonly property var transferPattern:/^\s*([+-]?\d*\.?\d+)\s*([a-zA-Z]+)\s*\/\s*([+-]?\d*\.?\d+)\s*([a-zA-Z]+)\s*$/i
    readonly property var mathFilter:/^[0-9+\-*/().,^ %a-zA-Z]+$/

    /*
     * #3 CURRENCY SETTINGS
     */

    readonly property var zeroDecimalCurrencies:["jpy","krw"]

    /*
     * #4 UNIT TABLE
     */

    readonly property var units:({

        /*
         * #4A LENGTH
         */

        mm:{category:"length",factor:0.001,label:"mm"},
        cm:{category:"length",factor:0.01,label:"cm"},
        m:{category:"length",factor:1,label:"m"},
        km:{category:"length",factor:1000,label:"km"},
        "in":{category:"length",factor:0.0254,label:"in"},
        ft:{category:"length",factor:0.3048,label:"ft"},
        yd:{category:"length",factor:0.9144,label:"yd"},
        mi:{category:"length",factor:1609.344,label:"mi"},

        /*
         * #4B MASS
         */

        mg:{category:"mass",factor:0.001,label:"mg"},
        g:{category:"mass",factor:1,label:"g"},
        kg:{category:"mass",factor:1000,label:"kg"},
        oz:{category:"mass",factor:28.349523125,label:"oz"},
        lb:{category:"mass",factor:453.59237,label:"lb"},
        st:{category:"mass",factor:6350.29318,label:"st"},
        ton:{category:"mass",factor:907184.74,label:"ton"},
        tonne:{category:"mass",factor:1000000,label:"tonne"},

        /*
         * #4C VOLUME
         */

        ml:{category:"volume",factor:0.001,label:"mL"},
        l:{category:"volume",factor:1,label:"L"},
        tsp:{category:"volume",factor:0.00492892,label:"tsp"},
        tbsp:{category:"volume",factor:0.0147868,label:"tbsp"},
        cup:{category:"volume",factor:0.236588,label:"cup"},
        pint:{category:"volume",factor:0.473176,label:"pint"},
        qt:{category:"volume",factor:0.946353,label:"qt"},
        gal:{category:"volume",factor:3.78541,label:"gal"},

        /*
         * #4D TIME
         */

        ms:{category:"time",factor:0.001,label:"ms"},
        sec:{category:"time",factor:1,label:"sec"},
        min:{category:"time",factor:60,label:"min"},
        hr:{category:"time",factor:3600,label:"hr"},
        day:{category:"time",factor:86400,label:"day"},
        week:{category:"time",factor:604800,label:"week"},

        /*
         * #4E SPEED
         */

        "m/s":{category:"speed",factor:1,label:"m/s"},
        "km/h":{category:"speed",factor:0.277778,label:"km/h"},
        mph:{category:"speed",factor:0.44704,label:"mph"},

        /*
         * #4F STORAGE
         */

        bits:{category:"storage",factor:0.125,label:"bits"},
        kbits:{category:"storage",factor:125,label:"kbits"},
        mbits:{category:"storage",factor:125000,label:"mbits"},
        gbits:{category:"storage",factor:125000000,label:"gbits"},
        tbits:{category:"storage",factor:125000000000,label:"tbits"},

        bytes:{category:"storage",factor:1,label:"bytes"},
        kbytes:{category:"storage",factor:1000,label:"KBytes"},
        mbytes:{category:"storage",factor:1000000,label:"MBytes"},
        gbytes:{category:"storage",factor:1000000000,label:"GBytes"},
        tbytes:{category:"storage",factor:1000000000000,label:"TBytes"},

        kib:{category:"storage",factor:1024,label:"KiB"},
        mib:{category:"storage",factor:1048576,label:"MiB"},
        gib:{category:"storage",factor:1073741824,label:"GiB"},
        tib:{category:"storage",factor:1099511627776,label:"TiB"},

        /*
         * #4G CURRENCY
         */

        usd:{category:"currency",factor:1.0,symbol:"$",label:"USD"},
        eur:{category:"currency",factor:0.92,symbol:"€",label:"EUR"},
        gbp:{category:"currency",factor:0.78,symbol:"£",label:"GBP"},
        ukd:{category:"currency",factor:0.78,symbol:"£",label:"UKD"},
        jpy:{category:"currency",factor:156.8,symbol:"¥",label:"JPY"},
        cny:{category:"currency",factor:7.24,symbol:"元",label:"CNY"},
        cad:{category:"currency",factor:1.37,symbol:"C$",label:"CAD"},
        aud:{category:"currency",factor:1.52,symbol:"A$",label:"AUD"},
        mxn:{category:"currency",factor:18.7,symbol:"$",label:"MXN"},
        brl:{category:"currency",factor:5.12,symbol:"R$",label:"BRL"},
        inr:{category:"currency",factor:83.2,symbol:"₹",label:"INR"},
        krw:{category:"currency",factor:1370,symbol:"₩",label:"KRW"},
        rub:{category:"currency",factor:89.5,symbol:"₽",label:"RUB"},
        chf:{category:"currency",factor:0.91,symbol:"CHF",label:"CHF"}
    })

    /*
     * #5 ALIASES
     */

    readonly property var aliases:({

        meter:"m",meters:"m",
        kilometer:"km",kilometers:"km",
        centimetre:"cm",centimetres:"cm",
        centimeter:"cm",centimeters:"cm",
        millimeter:"mm",millimeters:"mm",
        mile:"mi",miles:"mi",
        foot:"ft",feet:"ft",
        inch:"in",inches:"in",
        yard:"yd",yards:"yd",

        gram:"g",grams:"g",
        kilogram:"kg",kilograms:"kg",
        milligram:"mg",milligrams:"mg",
        ounce:"oz",ounces:"oz",
        pound:"lb",pounds:"lb",
        stone:"st",stones:"st",
        ton:"ton",tons:"ton",

        bit:"bits",bits:"bits",
        kbit:"kbits",kbits:"kbits",kb:"kbits",
        mbit:"mbits",mbits:"mbits",mb:"mbits",
        gbit:"gbits",gbits:"gbits",gb:"gbits",
        tbit:"tbits",tbits:"tbits",tb:"tbits",

        byte:"bytes",bytes:"bytes",B:"bytes",
        kbyte:"kbytes",kbytes:"kbytes",KB:"kbytes",
        mbyte:"mbytes",mbytes:"mbytes",MB:"mbytes",
        gbyte:"gbytes",gbytes:"gbytes",GB:"gbytes",
        tbyte:"tbytes",tbytes:"tbytes",TB:"tbytes",

        kib:"kib",kibibyte:"kib",
        mib:"mib",mebibyte:"mib",
        gib:"gib",gibibyte:"gib",
        tib:"tib",tebibyte:"tib",

        second:"sec",seconds:"sec",
        minute:"min",minutes:"min",
        hour:"hr",hours:"hr",
        day:"day",days:"day",
        week:"week",weeks:"week",

        "$":"usd",usd:"usd",
        "€":"eur",eur:"eur",
        "£":"gbp",gbp:"gbp",
        "¥":"jpy",jpy:"jpy",
        "元":"cny",cny:"cny",
        cad:"cad",aud:"aud",
        peso:"mxn",pesos:"mxn",
        real:"brl",reais:"brl",
        rupee:"inr",rupees:"inr"
    })

    /*
     * #6 STORAGE GROUPS
     */

    readonly property var storageGroups:[
        ["bits","bytes"],
        ["kbits","kbytes","kib"],
        ["mbits","mbytes","mib"],
        ["gbits","gbytes","gib"],
        ["tbits","tbytes","tib"]
    ]

    /*
     * #7 RESULT
     */

    function setResult(value) {
        mathResultString = String(value)
    }

    /*
     * #8 NORMALIZATION
     */

    function normalizeUnit(unit) {

        if (!unit)
            return ""

            unit = String(unit).trim()

            return aliases[unit] !== undefined
            ? aliases[unit]
            : unit
    }

    /*
     * #9 FORMATTERS
     */

    /*
     * #9A currencyDecimals
     */

    function currencyDecimals(unit) {
        return zeroDecimalCurrencies.includes(unit) ? 0 : 2
    }

    /*
     * #9B formatValue
     */

    /*
     * #9B formatValue
     */

    function formatValue(category,value,unitName) {

        /*
         * CURRENCY
         */

        if (category === "currency") {

            const decimals = currencyDecimals(unitName)

            const rounded = Number(
                Math.round(
                    Number(value) * Math.pow(10,decimals)
                ) / Math.pow(10,decimals)
            )

            return rounded.toLocaleString(
                undefined,
                {
                    minimumFractionDigits:decimals,
                    maximumFractionDigits:decimals,
                    useGrouping:true
                }
            )
        }

        /*
         * TIME
         */

        if (category === "time")
            return secondsToReadable(value)

            /*
             * STORAGE
             */

            if (category === "storage") {

                const abs = Math.abs(value)

                if (abs >= 100)
                    return Number(value).toFixed(0)

                    if (abs >= 10)
                        return Number(value).toFixed(1)

                        if (abs >= 1)
                            return Number(value).toFixed(2)

                            if (abs >= 0.01)
                                return Number(value).toFixed(4)

                                return Number(value).toExponential(2)
            }

            /*
             * GENERIC
             */

            if (Math.abs(value) >= 1000000)
                return Number(value).toExponential(4)

                return parseFloat(
                    Number(value).toFixed(6)
                ).toString()
    }
    /*
     * #9C padRight
     */

    function padRight(str,len) {

        str = String(str)

        while (str.length < len)
            str += " "

            return str
    }

    /*
     * #9D groupEntries
     */

    function groupEntries(entries,size) {

        return entries.join("\n")
    }
    /*
     * #10 TIME
     */

    /*
     * #10A secondsToReadable
     */

    function secondsToReadable(seconds) {

        seconds = Math.round(seconds)

        const days = Math.floor(seconds / 86400)
        seconds %= 86400

        const hours = Math.floor(seconds / 3600)
        seconds %= 3600

        const minutes = Math.floor(seconds / 60)
        seconds %= 60

        const parts = []

        if (days)
            parts.push(days + "d")

            if (hours)
                parts.push(hours + "h")

                if (minutes)
                    parts.push(minutes + "m")

                    if (seconds || !parts.length)
                        parts.push(seconds + "s")

                        return parts.join(" ")
    }

    /*
     * #10B calculateTransferTime
     */

    function calculateTransferTime(sizeValue,sizeUnit,speedValue,speedUnit) {

        sizeUnit = normalizeUnit(sizeUnit)
        speedUnit = normalizeUnit(speedUnit)

        const size = units[sizeUnit]
        const speed = units[speedUnit]

        if (!size || !speed)
            return false

            if (size.category !== "storage")
                return false

                if (speed.category !== "storage")
                    return false

                    const totalBytes = sizeValue * size.factor
                    const bytesPerSecond = speedValue * speed.factor

                    if (bytesPerSecond <= 0)
                        return false

                        const seconds = totalBytes / bytesPerSecond

                        setResult(
                            secondsToReadable(seconds)
                            + " @ "
                            + speedValue
                            + " "
                            + speedUnit
                        )

                        return true
    }

    /*
     * #11 STORAGE
     */

    function convertStorage(baseValue) {

        const grouped = []

        for (let i = 0; i < storageGroups.length; ++i) {

            const row = []

            for (let j = 0; j < storageGroups[i].length; ++j) {

                const unitKey = storageGroups[i][j]
                const unit = units[unitKey]
                const converted = baseValue / unit.factor

                row.push(
                    formatValue("storage",converted,unitKey)
                        + " "
                        + unit.label
                )
            }

            grouped.push(
                groupEntries(row,row.length,18)
            )
        }

        setResult(grouped.join("\n"))
        return true
    }

    /*
     * #12 CONVERSIONS
     */

    /*
     * #12A convertMeasurement
     */

    function convertMeasurement(value,fromUnit,targetUnit) {

        fromUnit = normalizeUnit(fromUnit)
        targetUnit = normalizeUnit(targetUnit)

        const source = units[fromUnit]

        if (!source)
            return false

            const category = source.category
            const baseValue = value * source.factor

            if (category === "storage" && !targetUnit)
                return convertStorage(baseValue)

                const entries = []

                for (let unitName in units) {

                    const unit = units[unitName]

                    if (unit.category !== category)
                        continue

                        if (targetUnit && unitName !== targetUnit)
                            continue

                            if (!targetUnit && unitName === fromUnit)
                                continue

                                const converted = (
                                    category === "currency"
                                    ? baseValue * unit.factor
                                    : baseValue / unit.factor
                                )

                                entries.push(
                                    formatValue(category,converted,unitName)
                                        + " "
                                        + (unit.label || unitName)
                                        + (unit.symbol ? (" " + unit.symbol) : "")
                                )
                }

                if (category === "currency" && !targetUnit) {

                    setResult(
                        groupEntries(entries,3,24)
                    )

                    return true
                }

                setResult(entries.join("\n"))
                return true
    }

    /*
     * #12B convertTemperature
     */

    function convertTemperature(value,fromUnit,targetUnit) {

        fromUnit = fromUnit.toLowerCase()
        targetUnit = targetUnit ? targetUnit.toLowerCase() : ""

        if (fromUnit !== "c" && fromUnit !== "f")
            return false

            const results = []

            if ((!targetUnit || targetUnit === "f") && fromUnit !== "f")
                results.push(
                    formatValue("generic",(value * 9 / 5) + 32)
                        + " F"
                )

                if ((!targetUnit || targetUnit === "c") && fromUnit !== "c")
                    results.push(
                        formatValue("generic",(value - 32) * 5 / 9)
                            + " C"
                    )

                    setResult(results.join("\n"))
                    return true
    }

    /*
     * #13 CALCULATOR
     */

    function runCalculator(query) {

        const clean = (query || "").trim()

        if (!clean)
            return false

            /*
             * #13A TRANSFER TIME
             */

            const transferMatch = clean.match(transferPattern)

            if (transferMatch) {

                const sizeValue = parseFloat(transferMatch[1])
                const sizeUnit = transferMatch[2]
                const speedValue = parseFloat(transferMatch[3])
                const speedUnit = transferMatch[4]

                if (
                    calculateTransferTime(
                        sizeValue,
                        sizeUnit,
                        speedValue,
                        speedUnit
                    )
                ) {
                    return true
                }
            }

            /*
             * #13B UNIT CONVERSION
             */

            const match = clean.match(conversionPattern)

            if (match) {

                const value = parseFloat(
                    String(match[1]).replace(/[$€£¥₹₩₽元]/g,"")
                )

                let fromUnit = normalizeUnit(match[2])
                let targetUnit = normalizeUnit(match[3] || "")

                if (convertTemperature(value,fromUnit,targetUnit))
                    return true

                    if (convertMeasurement(value,fromUnit,targetUnit))
                        return true
            }

            /*
             * #13C MATH
             */

            if (!mathFilter.test(clean))
                return false

                try {

                    const expression = clean
                    .replace(/\^/g,"**")
                    .replace(/\bpi\b/gi,"Math.PI")
                    .replace(/\be\b/g,"Math.E")
                    .replace(/\bsin\b/gi,"Math.sin")
                    .replace(/\bcos\b/gi,"Math.cos")
                    .replace(/\btan\b/gi,"Math.tan")
                    .replace(/\bsqrt\b/gi,"Math.sqrt")
                    .replace(/\blog\b/gi,"Math.log10")
                    .replace(/\bln\b/gi,"Math.log")

                    const result = eval(expression)

                    if (!isFinite(result))
                        return false

                        setResult(
                            formatValue("generic",result)
                        )

                        return true

                } catch (e) {

                    return false
                }
    }
}
