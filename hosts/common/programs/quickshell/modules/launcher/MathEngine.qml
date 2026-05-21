import QtQuick

QtObject {
    id: mathEngine

    // === THEME VARIABLES: GROUPED AT TOP ===
    property int fontSize: 20
    property color mainColor: "#F7F700"
    property color backgroundColor: "#1a1a1a"
    property color borderColor: "#F7F700"
    property int borderRadius: 8
    property int borderWidth: 2
    // Note: No visible UI in this object currently

    property var root

    function runMeasurementConversion(lowerQuery) {

        let match =
        lowerQuery.match(
            /^([0-9.]+)\s*([a-zA-Z]+)(?:\s+to\s+([a-zA-Z]+))?$/
        )

        if (!match)
            return false

            let value =
            parseFloat(match[1])

            let from =
            match[2].toLowerCase()

            let target =
            match[3]
            ? match[3].toLowerCase()
            : ""

            let categories = {

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

            let matchedCategory = null

            for (let category in categories) {

                if (
                    categories[category][from]
                    !== undefined
                ) {

                    matchedCategory =
                    categories[category]

                    break
                }
            }

            if (!matchedCategory)
                return false

                let baseValue =
                value * matchedCategory[from]

                let results = []

                for (let key in matchedCategory) {

                    let converted =
                    baseValue
                    / matchedCategory[key]

                    let line =
                    converted.toFixed(4)
                    + " "
                    + key

                    if (
                        target.length === 0
                        || line.toLowerCase().includes(target)
                    ) {

                        results.push(line)
                    }
                }

                root.isMathMode = true

                root.mathResultString =
                results.join("\n")

                return true
    }

    function runCalculator(cleanQuery) {

        if (
            cleanQuery.length <= 0
            || !/^[0-9a-zA-Z+\-*/().\s,]+$/
            .test(cleanQuery)
        ) {
            return false
        }

        try {

            let mathExpression =
            cleanQuery.replace(
                /\b(sin|cos|tan|sqrt|log|ln|pow|abs|round|floor|ceil|PI|E)\b/gi,
                               function(match) {

                                   if (
                                       match.toLowerCase()
                                       === "ln"
                                   ) {
                                       return "Math.log"
                                   }

                                   if (
                                       match.toUpperCase()
                                       === "PI"
                                   ) {
                                       return "Math.PI"
                                   }

                                   if (
                                       match.toUpperCase()
                                       === "E"
                                   ) {
                                       return "Math.E"
                                   }

                                   return "Math."
                                   + match.toLowerCase()
                               }
            )

            let result =
            Function(
                `"use strict"; return (${mathExpression})`
            )()

            if (
                typeof result === "number"
                && !Number.isInteger(result)
            ) {

                result =
                parseFloat(
                    result.toFixed(6)
                )
            }

            root.isMathMode = true

            root.mathResultString =
            String(result)

            return true

        } catch (e) {

            return false
        }
    }
}
