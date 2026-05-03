import CuaDriverCore
import Foundation
import MCP

/// Force character-by-character CGEvent text input to a specific pid.
///
/// This is the explicit fallback for web/Electron inputs where the AX
/// `type_text` path can report success without firing the renderer's
/// keyboard/input handlers.
public enum TypeTextCharsTool {
    public static let handler = ToolHandler(
        tool: Tool(
            name: "type_text_chars",
            description: """
                Type text as per-character Unicode key events delivered
                directly to the target pid via `CGEvent.postToPid` /
                SkyLight. Use this when a web/Electron input is focused but
                `type_text` does not visibly update the field or trigger the
                page's input handlers.

                Optional `element_index` + `window_id` (from the latest
                `get_window_state` for that window) focuses the element
                before typing. Without it, characters go to the pid's current
                keyboard focus.

                Special keys (Return, Escape, arrows, Tab) are not text; use
                `press_key` / `hotkey` for those.
                """,
            inputSchema: [
                "type": "object",
                "required": ["pid", "text"],
                "properties": [
                    "pid": [
                        "type": "integer",
                        "description": "Target process ID.",
                    ],
                    "text": [
                        "type": "string",
                        "description": "Text to type as Unicode key events.",
                    ],
                    "delay_ms": [
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 200,
                        "description":
                            "Milliseconds between characters. Default 30; use 25-50 for web inputs with autocomplete.",
                    ],
                    "element_index": [
                        "type": "integer",
                        "description":
                            "Optional element_index from the last get_window_state for the same (pid, window_id). When present, the element is focused before typing. Requires window_id.",
                    ],
                    "window_id": [
                        "type": "integer",
                        "description":
                            "CGWindowID for the window whose get_window_state produced the element_index. Required when element_index is used.",
                    ],
                ],
                "additionalProperties": false,
            ],
            annotations: .init(
                readOnlyHint: false,
                destructiveHint: true,
                idempotentHint: false,
                openWorldHint: true
            )
        ),
        invoke: { arguments in
            guard let rawPid = arguments?["pid"]?.intValue else {
                return errorResult("Missing required integer field pid.")
            }
            guard let text = arguments?["text"]?.stringValue else {
                return errorResult("Missing required string field text.")
            }
            let delayMs = arguments?["delay_ms"]?.intValue ?? 30
            let elementIndex = arguments?["element_index"]?.intValue
            let rawWindowId = arguments?["window_id"]?.intValue
            guard let pid = Int32(exactly: rawPid) else {
                return errorResult(
                    "pid \(rawPid) is outside the supported Int32 range.")
            }
            if elementIndex != nil && rawWindowId == nil {
                return errorResult(
                    "window_id is required when element_index is used — the "
                    + "element_index cache is scoped per (pid, window_id). Pass "
                    + "the same window_id you used in `get_window_state`.")
            }

            do {
                if let index = elementIndex, let rawWindowId {
                    guard let windowId = UInt32(exactly: rawWindowId) else {
                        return errorResult(
                            "window_id \(rawWindowId) is outside the supported UInt32 range.")
                    }
                    let element = try await AppStateRegistry.engine.lookup(
                        pid: pid,
                        windowId: windowId,
                        elementIndex: index)
                    try await AppStateRegistry.focusGuard.withFocusSuppressed(
                        pid: pid, element: element
                    ) {
                        try? AXInput.setAttribute(
                            "AXFocused",
                            on: element,
                            value: kCFBooleanTrue as CFTypeRef
                        )
                        try KeyboardInput.typeCharacters(
                            text,
                            delayMilliseconds: delayMs,
                            toPid: pid
                        )
                    }
                    let target = AXInput.describe(element)
                    return CallTool.Result(
                        content: [
                            .text(
                                text:
                                    "✅ Focused [\(index)] \(target.role ?? "?") and typed \(text.count) char(s) on pid \(rawPid) via CGEvent (\(delayMs)ms delay).",
                                annotations: nil, _meta: nil)
                        ]
                    )
                }

                try KeyboardInput.typeCharacters(
                    text,
                    delayMilliseconds: delayMs,
                    toPid: pid
                )
                return CallTool.Result(
                    content: [
                        .text(
                            text:
                                "✅ Typed \(text.count) char(s) on pid \(rawPid) via CGEvent (\(delayMs)ms delay).",
                            annotations: nil, _meta: nil)
                    ]
                )
            } catch let error as AppStateError {
                return errorResult(error.description)
            } catch let error as KeyboardError {
                return errorResult(error.description)
            } catch {
                return errorResult("Unexpected error: \(error)")
            }
        }
    )

    private static func errorResult(_ message: String) -> CallTool.Result {
        CallTool.Result(
            content: [.text(text: message, annotations: nil, _meta: nil)],
            isError: true
        )
    }
}
