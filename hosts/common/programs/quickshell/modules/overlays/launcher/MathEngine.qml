pragma Singleton

import QtQuick

QtObject {
    id: root

    property var shellRoot

    function setResult(result) {
        shellRoot.isMathMode = true
        shellRoot.mathResultString = String(result)
    }

    function runMeasurementConversion(query) {
        const match = query.match(
            /^([0-9.]+)\s*([a-zA-Z]+)(?:\s+to\s+([a-zA-Z]+))?$/
        )

        if (!match) {
            return false
        }

        const value = parseFloat(match[1])
        const from = match[2].toLowerCase()
        const target = match[3] ? match[3].toLowerCase() : ""

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

        let units = null

        for (let key in categories) {
            if (categories[key][from] !== undefined) {
                units = categories[key]
                break
            }
        }

        if (!units) {
            return false
        }

        const baseValue = value * units[from]

        let results = []

        for (let unit in units) {
            const converted = baseValue / units[unit]
            const line = `${converted.toFixed(4)} ${unit}`

            if (!target || line.includes(target)) {
                results.push(line)
            }
        }

        setResult(results.join("\n"))

        return true
    }

    function runCalculator(query) {
        const cleanQuery = query.trim()

        if (
            cleanQuery.length === 0 ||
            !/^[0-9a-zA-Z+\-*/().\s,]+$/.test(cleanQuery)
        ) {
            return false
        }

        try {
            const expression = cleanQuery.replace(
                /\b(sin|cos|tan|sqrt|log|ln|pow|abs|round|floor|ceil|PI|E)\b/gi,
                                                  function(match) {
                                                      if (match.toLowerCase() === "ln") {
                                                          return "Math.log"
                                                      }

                                                      if (match.toUpperCase() === "PI") {
                                                          return "Math.PI"
                                                      }

                                                      if (match.toUpperCase() === "E") {
                                                          return "Math.E"
                                                      }

                                                      return "Math." + match.toLowerCase()
                                                  }
            )

            let result = Function(
                `"use strict"; return (${expression})`
            )()

            if (typeof result === "number" && !Number.isInteger(result)) {
                result = parseFloat(result.toFixed(6))
            }

            setResult(result)

            return true
        } catch (error) {
            console.log("Math evaluation failed:", error)
            return false
        }
    }
}
