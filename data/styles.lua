local styles = data.raw["gui-style"].default

styles["tro_trades_list"] = {
    type = "scroll_pane_style",
    horizontally_stretchable = "on"
}

styles["tro_trade_row"] = {
    type = "frame_style",
    horizontally_stretchable = "on",
}

styles["tro_trade_row_flow"] = {
  type = "horizontal_flow_style",
  horizontally_stretchable = "on",
  vertical_align = "center"
}

styles["tro_trade_group"] = {
    type = "frame_style"
}

styles["tro_trade_group_button"] = {
    type = "button_style",
}

styles["tro_page_index_root"] = {
    type = "frame_style",
    left_padding = 24,
    right_padding = 24,
}

styles["tro_page_index_button_flow"] = {
    type="horizontal_flow_style",
    horizontally_stretchable = "stretch_and_expand",
    horizontal_spacing = 10,
    horizontal_align = "center",
}

styles["tro_page_index_button"] = {
    type = "button_style",
    minimal_width = 0,
}

styles["tro_trades_gui"] = {
    type = "frame_style",
    size = {800, 700},
}