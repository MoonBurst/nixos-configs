pragma Singleton

import QtQuick

QtObject {
    id: root

    /*
     * OUTPUT
     */

    property string mathResultString: ""

    /*
     * SET RESULT
     */

    function setResult(result) {
        mathResultString = String(result)
    }

    /*
     * MEASUREMENT CONVERSION
     */

    function runMeasurementConversion(query) {

        /*
         * EXAMPLES:
         *
         * 5km
         * 5 km
         * 5 km to mi
         * 10ft to m
         * 12 miles to km
         */

        const match = query.match(
            /^([0-9.]+)\s*([a-zA-Z]+)(?:\s+(?:to|in)\s+([a-zA-Z]+))?$/
        )

        if (!match) {
            return false
        }

        const value =
        parseFloat(match[1])

        let from =
        match[2].toLowerCase()

        let target =
        match[3]
        ? match[3].toLowerCase()
        : ""

        /*
         * ALIASES
         */

        const aliases = {

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
        }

        if (aliases[from]) {
            from = aliases[from]
        }

        if (aliases[target]) {
            target = aliases[target]
        }

        /*
         * CATEGORIES
         */

        const categories = {

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
        }

        /*
         * FIND UNIT GROUP
         */

        let units = null

        for (let key in categories) {

            if (
                categories[key][from] !== undefined
            ) {
                units = categories[key]
                break
            }
        }

        if (!units) {
            return false
        }

        /*
         * CONVERT
         */

        const baseValue =
        value * units[from]

        let results = []

        for (let unit in units) {

            const converted =
            baseValue / units[unit]

            const line =
            `${converted.toFixed(4)} ${unit}`

            if (
                !target ||
                unit === target
            ) {
                results.push(line)
            }
        }

        /*
         * NO MATCH
         */

        if (results.length === 0) {
            return false
        }

        setResult(results.join("\n"))

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

        if (cleanQuery.length === 0) {
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
         * MATH DETECTION
         */

        const looksLikeMath =
        /[0-9+\-*/().^]/.test(
            cleanQuery
        )

        if (!looksLikeMath) {
            return false
        }

        try {

            /*
             * START
             */

            let expression =
            cleanQuery

            /*
             * EXPONENTS
             *
             * 2^8
             */

            expression =
            expression.replace(
                /\^/g,
                "**"
            )

            /*
             * IMPLICIT PI
             *
             * 2PI
             */

            expression =
            expression.replace(
                /([0-9])PI/g,
                               "$1*Math.PI"
            )

            /*
             * IMPLICIT E
             *
             * 2E
             */

            expression =
            expression.replace(
                /([0-9])E/g,
                               "$1*Math.E"
            )

            /*
             * FUNCTIONS
             */

            expression =
            expression.replace(
                /\b(sin|cos|tan|sqrt|log|ln|pow|abs|round|floor|ceil|PI|E)\b/gi,
                               function(match) {

                                   if (
                                       match.toLowerCase() === "ln"
                                   ) {
                                       return "Math.log"
                                   }

                                   if (
                                       match.toUpperCase() === "PI"
                                   ) {
                                       return "Math.PI"
                                   }

                                   if (
                                       match.toUpperCase() === "E"
                                   ) {
                                       return "Math.E"
                                   }

                                   return (
                                       "Math." +
                                       match.toLowerCase()
                                   )
                               }
            )

            /*
             * EXECUTE
             */

            let result = Function(
                `"use strict"; return (${expression})`
            )()

            /*
             * INVALID
             */

            if (
                typeof result !== "number" ||
                isNaN(result)
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

            /*
             * STORE RESULT
             */

            setResult(result)

            return true

        } catch(error) {

            return false
        }
    }
}
