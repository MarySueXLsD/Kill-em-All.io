require engine.core

module input public


def public init_input() {
    add_and_activate_action_set("player", {
        "move" => Action(
            joystickActions = JoystickAction(
                keyboardDPads = [KeyboardDPadInput(leftIdx = KeyCode.A, rightIdx = KeyCode.D, upIdx = KeyCode.W, downIdx = KeyCode.S)],
                gamepadDPads = [GamepadDPadInput(leftIdx = GamepadButton.Left, rightIdx = GamepadButton.Right, upIdx = GamepadButton.Up, downIdx = GamepadButton.Down)],
                sticks = [GamepadStickInput(xIdx = GamepadAxis.LThumbH, yIdx = GamepadAxis.LThumbV)]
            )
        ),
        "run" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [
                    KeyboardButtonInput(idx = KeyCode.LShift),
                    KeyboardButtonInput(idx = KeyCode.Rshift)
                ],
                gamepadButtons = [GamepadButtonInput(idx = GamepadButton.X)]
            )
        ),
        "dash" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx = KeyCode.Space)],
                gamepadButtons = [GamepadButtonInput(idx = GamepadButton.B)]
            )
        ),
        "weaponSwitch" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [
                    KeyboardButtonInput(idx = KeyCode.E),
                    KeyboardButtonInput(idx = KeyCode.Q)
                ]
            )
        ),
        "weaponScroll" => Action(
            axisActions = AxisAction(
                mouseAxis = [MouseBtnAxisInput(
                    positiveIdx = MouseButton.WheelUp,
                    negativeIdx = MouseButton.WheelDown,
                    sensitivity = 1.0
                )]
            )
        ),
        "cursor" => Action(
            pointerActions = PointerAction(
                valueType = ValueType.Accumulate,
                mouse = MouseInput(active = true)
            )
        ),
        "attack" => Action(
            buttonActions = ButtonAction(
                mouseButtons = [MouseButtonInput(idx = MouseButton.Left)]
            )
        ),
        "special" => Action(
            buttonActions = ButtonAction(
                mouseButtons = [MouseButtonInput(idx = MouseButton.Right)]
            )
        ),
        "tileAngleUp" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx = KeyCode.Up)]
            )
        ),
        "tileAngleDown" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx = KeyCode.Down)]
            )
        ),
        "debugBorders" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx = KeyCode._1)]
            )
        ),
        "debugToggleEnemies" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx = KeyCode._2)]
            )
        ),
        "debugToggleHud" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx = KeyCode._3)]
            )
        ),
        "skipDisclaimer" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [
                    KeyboardButtonInput(idx = KeyCode.Return),
                    KeyboardButtonInput(idx = KeyCode.Space)
                ],
                gamepadButtons = [GamepadButtonInput(idx = GamepadButton.Start)]
            )
        )
    })
}
