pragma Singleton

import QtQuick

QtObject {
    id: root

    /*
     * OUTPUT
     */

    property string mathResultString: ""

    readonly property
    var unitAliases: ({

        /*
         * DISTANCE
         */
        mile: "mi",
        miles: "mi",
        meter: "m",
        meters: "m",
        kilometre: "km",
        kilometres: "km",
        kilometer: "km",
        kilometers: "km",
        foot: "ft",
        feet: "ft",
        inch: "in",
        inches: "in",
        yard: "yd",
        yards: "yd",

        /*
         * WEIGHT
         */
        gram: "g",
        grams: "g",
        kilogram: "kg",
        kilograms: "kg",
        pound: "lb",
        pounds: "lb",
        ounce: "oz",
        ounces: "oz",

        /*
         * LIQUID
         */
        liter: "l",
        liters: "l",
        litre: "l",
        litres: "l",
        gallon: "gal",
        gallons: "gal",
        cup: "cup",
        cups: "cup"
    })

    readonly property
    var unitCategories: ({

        distance: {
            mm: 0.001,
            cm: 0.01,
            m: 1,
            km: 1000,
            in: 0.0254,
            ft: 0.3048,
            yd: 0.9144,
            mi: 1609.34
        },

        weight: {
            mg: 0.001,
            g: 1,
            kg: 1000,
            oz: 28.3495,
            lb: 453.592
        },

        liquid: {
            ml: 1,
            l: 1000,
            cup: 236.588,
            pint: 473.176,
            gal: 3785.41
        }
    })

    readonly property
    var mathFunctionMap: ({
        sin: "Math.sin",
        cos: "Math.cos",
        tan: "Math.tan",
        sqrt: "Math.sqrt",
        log: "Math.log10",
        ln: "Math.log",
        pow: "Math.pow",
        abs: "Math.abs",
        round: "Math.round",
        floor: "Math.floor",
        ceil: "Math.ceil",
        pi: "Math.PI",
        e: "Math.E"
    })

    /*
     * SET RESULT
     */

    function setResult(result) {
        mathResultString =
        String(result)
    }

    /*
     * UNIT CONVERSION
     */

    function runMeasurementConversion(query) {

        const match =
        query.match(
            /^([0-9.]+)\s*([a-zA-Z]+)(?:\s+(?:to|in)\s+([a-zA-Z]+))?$/
        )

        if (!match) {
            return false
        }

        const value =
        parseFloat(match[1])

        if (isNaN(value)) {
            return false
        }

        let from =
        match[2].toLowerCase()

        let target =
        match[3] ?
        match[3].toLowerCase() :
        ""

        from =
        unitAliases[from] ||
        from

        target =
        unitAliases[target] ||
        target

        /*
         * FIND UNIT GROUP
         */

        let units = null

        const categories =
        unitCategories

        for (let key in categories) {
            const category =
            categories[key]

            if (
                category[from] !== undefined
            ) {
                units = category
                break
            }
        }

        if (
            !units ||
            (
                target &&
                units[target] === undefined
            )
        ) {
            return false
        }

        /*
         * CONVERT
         */

        const baseValue =
        value * units[from]

        const results = []

        for (let unit in units) {

            if (
                target &&
                unit !== target
            ) {
                continue
            }

            results.push(
                (
                    baseValue /
                    units[unit]
                ).toFixed(4) +
                " " +
                unit
            )
        }

        if (!results.length) {
            return false
        }

        setResult(
            results.join("\n")
        )

        return true
    }

    /*
     * CALCULATOR
     */

    function runCalculator(query) {

        const cleanQuery =
        (query || "").trim()

        /*
         * EMPTY
         */

        if (!cleanQuery) {
            return false
        }

        /*
         * UNIT CONVERSION
         */

        if (
            runMeasurementConversion(
                cleanQuery
            )
        ) {
            return true
        }

        /*
         * QUICK MATH DETECTION
         */

        if (
            !/[0-9+\-*/().^]/.test(
                cleanQuery
            )
        ) {
            return false
        }

        try {

            let expression =
            cleanQuery

            /*
             * EXPONENTS
             */

            expression =
            expression.replace(
                /\^/g,
                "**"
            )

            /*
             * IMPLICIT CONSTANTS
             */

            expression =
            expression.replace(
                /([0-9])PI/gi,
                               "$1*Math.PI"
            )

            expression =
            expression.replace(
                /([0-9])E\b/g,
                               "$1*Math.E"
            )

            /*
             * FUNCTIONS
             */

            expression =
            expression.replace(
                /\b(sin|cos|tan|sqrt|log|ln|pow|abs|round|floor|ceil|PI|E)\b/gi,
                               function(match) {

                                   return (
                                       mathFunctionMap[
                                           match.toLowerCase()
                                       ] || match
                                   )
                               }
            )

            /*
             * EXECUTE
             */

            let result =
            Function(
                `"use strict"; return (${expression})`
            )()

            /*
             * VALIDATE
             */

            if (
                typeof result !== "number" ||
                !isFinite(result)
            ) {
                return false
            }

            /*
             * ROUND FLOATS
             */

            if (
                !Number.isInteger(result)
            ) {
                result =
                parseFloat(
                    result.toFixed(6)
                )
            }

            setResult(result)

            return true

        } catch (error) {

            return false
        }
    }
}
