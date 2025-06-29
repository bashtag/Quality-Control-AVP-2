
//
//  ReportGenerator.swift
//  Quality Control
//
//  Created by Melike SEYİTOĞLU on 9.12.2024.
//

import Foundation
import libxlsxwriter

class ReportGenerator {
    private var object: VirtualObject
    private(set) var filePath: String

    init(for virtualObject: VirtualObject, reportsDirectory: String) {
        self.object = virtualObject
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let fileName = "\(virtualObject.name)_\(timestamp).xlsx"
        self.filePath = (reportsDirectory as NSString).appendingPathComponent(fileName)
    }

    /// Creates a new Excel report file.
    func createReport() throws {
        guard let workbook = workbook_new(filePath) else {
            throw NSError(domain: "ReportGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create workbook"])
        }
        
        guard let worksheet = workbook_add_worksheet(workbook, nil) else {
            workbook_close(workbook)
            throw NSError(domain: "ReportGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create worksheet"])
        }

        // Set column widths for better readability
        worksheet_set_column(worksheet, 0, 0, 20, nil) // Column A
        worksheet_set_column(worksheet, 1, 1, 15, nil) // Column B
        worksheet_set_column(worksheet, 2, 2, 30, nil) // Column C
        worksheet_set_column(worksheet, 3, 3, 15, nil) // Column D

        var currentRow: lxw_row_t = 0
        
        // Write object info with better spacing
        writeString("OBJECT INFORMATION", to: worksheet, row: currentRow, col: 0)
        currentRow += 1
        
        writeString("Object Name:", to: worksheet, row: currentRow, col: 0)
        writeString(object.name, to: worksheet, row: currentRow, col: 1)
        currentRow += 1

        writeString("Width (m):", to: worksheet, row: currentRow, col: 0)
        writeNumber(object.width, to: worksheet, row: currentRow, col: 1)
        currentRow += 1

        writeString("Height (m):", to: worksheet, row: currentRow, col: 0)
        writeNumber(object.height, to: worksheet, row: currentRow, col: 1)
        currentRow += 1

        writeString("Depth (m):", to: worksheet, row: currentRow, col: 0)
        writeNumber(object.depth, to: worksheet, row: currentRow, col: 1)
        currentRow += 1
        
        writeString("Report Generated:", to: worksheet, row: currentRow, col: 0)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        writeString(formatter.string(from: Date()), to: worksheet, row: currentRow, col: 1)
        currentRow += 2 // Extra blank line

        // Write inspection points section
        if !object.inspectionPoints.isEmpty {
            writeString("INSPECTION POINTS", to: worksheet, row: currentRow, col: 0)
            currentRow += 1
            
            // Headers with better spacing
            writeString("Inspection Name", to: worksheet, row: currentRow, col: 0)
            writeString("Count", to: worksheet, row: currentRow, col: 1)
            writeString("Description", to: worksheet, row: currentRow, col: 2)
            writeString("Is Correct", to: worksheet, row: currentRow, col: 3)
            currentRow += 1

            for point in object.inspectionPoints {
                writeString(point.name, to: worksheet, row: currentRow, col: 0)

                // Count
                if point.hasCount, let countVal = point.count {
                    writeNumber(Double(countVal), to: worksheet, row: currentRow, col: 1)
                } else {
                    writeString("N/A", to: worksheet, row: currentRow, col: 1)
                }

                // Description
                if point.hasDescription, let descVal = point.description {
                    writeString(descVal, to: worksheet, row: currentRow, col: 2)
                } else {
                    writeString("No description", to: worksheet, row: currentRow, col: 2)
                }

                // Is Correct
                if point.hasIsCorrect, let correctVal = point.isCorrect {
                    writeString(correctVal ? "Yes" : "No", to: worksheet, row: currentRow, col: 3)
                } else {
                    writeString("Not evaluated", to: worksheet, row: currentRow, col: 3)
                }

                currentRow += 1
            }
            currentRow += 2 // Extra blank line after inspection points
        }

        // Write annotations section
        if !object.annotations.isEmpty {
            writeString("ANNOTATIONS", to: worksheet, row: currentRow, col: 0)
            currentRow += 1
            
            // Headers with better spacing
            writeString("Annotation Title", to: worksheet, row: currentRow, col: 0)
            writeString("Description", to: worksheet, row: currentRow, col: 1)
            writeString("Yes/No Answer", to: worksheet, row: currentRow, col: 2)
            currentRow += 1

            for annotation in object.annotations {
                writeString(annotation.title, to: worksheet, row: currentRow, col: 0)
                writeString(annotation.description, to: worksheet, row: currentRow, col: 1)
                writeString(annotation.yesNoAnswerText, to: worksheet, row: currentRow, col: 2)
                currentRow += 1
            }
            currentRow += 2 // Extra blank line after annotations
        }

        // Write summary section
        writeString("SUMMARY STATISTICS", to: worksheet, row: currentRow, col: 0)
        currentRow += 1
        
        writeString("Total Inspection Points:", to: worksheet, row: currentRow, col: 0)
        writeNumber(Double(object.inspectionPoints.count), to: worksheet, row: currentRow, col: 1)
        currentRow += 1
        
        writeString("Total Annotations:", to: worksheet, row: currentRow, col: 0)
        writeNumber(Double(object.annotations.count), to: worksheet, row: currentRow, col: 1)
        currentRow += 1
        
        // Annotation answer summary
        if !object.annotations.isEmpty {
            currentRow += 1 // Blank line
            writeString("ANNOTATION BREAKDOWN", to: worksheet, row: currentRow, col: 0)
            currentRow += 1
            
            let yesCount = object.annotations.filter { $0.yesNoAnswer == true }.count
            let noCount = object.annotations.filter { $0.yesNoAnswer == false }.count
            let notSetCount = object.annotations.filter { $0.yesNoAnswer == nil }.count
            
            writeString("Yes Answers:", to: worksheet, row: currentRow, col: 0)
            writeNumber(Double(yesCount), to: worksheet, row: currentRow, col: 1)
            currentRow += 1
            
            writeString("No Answers:", to: worksheet, row: currentRow, col: 0)
            writeNumber(Double(noCount), to: worksheet, row: currentRow, col: 1)
            currentRow += 1
            
            writeString("Not Set Answers:", to: worksheet, row: currentRow, col: 0)
            writeNumber(Double(notSetCount), to: worksheet, row: currentRow, col: 1)
            currentRow += 1
        }

        workbook_close(workbook)
    }

    /// Updates the existing report by regenerating it with appended inspection points and annotations.
    func updateReport(with newInspections: [InspectionPoint], newAnnotations: [ReportAnnotation] = []) throws {
        let updatedObject = VirtualObject(
            name: object.name,
            width: object.width,
            height: object.height,
            depth: object.depth,
            inspectionPoints: object.inspectionPoints + newInspections,
            annotations: object.annotations + newAnnotations
        )

        self.object = updatedObject
        try createReport()
    }

    // MARK: - Helper Writing Functions

    private func writeString(_ string: String, to worksheet: UnsafeMutablePointer<lxw_worksheet>, row: lxw_row_t, col: lxw_col_t) {
        worksheet_write_string(worksheet, row, col, string, nil)
    }

    private func writeNumber(_ number: Double, to worksheet: UnsafeMutablePointer<lxw_worksheet>, row: lxw_row_t, col: lxw_col_t) {
        worksheet_write_number(worksheet, row, col, number, nil)
    }
}

//
//class ReportGenerator {
//    private var object: VirtualObject
//    private(set) var filePath: String
//
//    init(for virtualObject: VirtualObject, reportsDirectory: String) {
//        self.object = virtualObject
//        let fileName = "\(virtualObject.name)_\(UUID().uuidString).xlsx"
//        self.filePath = (reportsDirectory as NSString).appendingPathComponent(fileName)
//    }
//
//    /// Creates a new Excel report file.
//    func createReport() throws {
//        guard let workbook = workbook_new(filePath) else {
//            throw NSError(domain: "ReportGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create workbook"])
//        }
//        
//        guard let worksheet = workbook_add_worksheet(workbook, nil) else {
//            workbook_close(workbook)
//            throw NSError(domain: "ReportGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create worksheet"])
//        }
//
//        // Write object info
//        writeString("Object Name", to: worksheet, row: 0, col: 0)
//        writeString(object.name, to: worksheet, row: 0, col: 1)
//
//        writeString("Width", to: worksheet, row: 1, col: 0)
//        writeNumber(object.width, to: worksheet, row: 1, col: 1)
//
//        writeString("Height", to: worksheet, row: 2, col: 0)
//        writeNumber(object.height, to: worksheet, row: 2, col: 1)
//
//        writeString("Depth", to: worksheet, row: 3, col: 0)
//        writeNumber(object.depth, to: worksheet, row: 3, col: 1)
//
//        // Blank line
//        writeString("Inspection Points", to: worksheet, row: 5, col: 0)
//        writeString("Name", to: worksheet, row: 6, col: 0)
//        writeString("Count", to: worksheet, row: 6, col: 1)
//        writeString("Description", to: worksheet, row: 6, col: 2)
//        writeString("Correct", to: worksheet, row: 6, col: 3)
//
//        var currentRow: lxw_row_t = 7
//        for point in object.inspectionPoints {
//            writeString(point.name, to: worksheet, row: currentRow, col: 0)
//
//            // Count
//            if point.hasCount, let countVal = point.count {
//                writeNumber(Double(countVal), to: worksheet, row: currentRow, col: 1)
//            } else {
//                writeString("-", to: worksheet, row: currentRow, col: 1)
//            }
//
//            // Description
//            if point.hasDescription, let descVal = point.description {
//                writeString(descVal, to: worksheet, row: currentRow, col: 2)
//            } else {
//                writeString("-", to: worksheet, row: currentRow, col: 2)
//            }
//
//            // Is Correct
//            if point.hasIsCorrect, let correctVal = point.isCorrect {
//                writeString(correctVal ? "Yes" : "No", to: worksheet, row: currentRow, col: 3)
//            } else {
//                writeString("-", to: worksheet, row: currentRow, col: 3)
//            }
//
//            currentRow += 1
//        }
//
//        workbook_close(workbook)
//    }
//
//    /// Updates the existing report by regenerating it with appended inspection points.
//    func updateReport(with newInspections: [InspectionPoint]) throws {
//        let updatedObject = VirtualObject(
//            name: object.name,
//            width: object.width,
//            height: object.height,
//            depth: object.depth,
//            inspectionPoints: object.inspectionPoints + newInspections
//        )
//
//        self.object = updatedObject
//        try createReport()
//    }
//
//    // MARK: - Helper Writing Functions
//
//    private func writeString(_ string: String, to worksheet: UnsafeMutablePointer<lxw_worksheet>, row: lxw_row_t, col: lxw_col_t) {
//        worksheet_write_string(worksheet, row, col, string, nil)
//    }
//
//    private func writeNumber(_ number: Double, to worksheet: UnsafeMutablePointer<lxw_worksheet>, row: lxw_row_t, col: lxw_col_t) {
//        worksheet_write_number(worksheet, row, col, number, nil)
//    }
//}
