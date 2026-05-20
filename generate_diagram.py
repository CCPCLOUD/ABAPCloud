from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches, Pt
import copy

prs = Presentation()
prs.slide_width  = Inches(20)
prs.slide_height = Inches(50)

blank_layout = prs.slide_layouts[6]

# ── helpers ──────────────────────────────────────────────────────────────────

def rgb(hex_str):
    h = hex_str.lstrip('#')
    return RGBColor(int(h[0:2],16), int(h[2:4],16), int(h[4:6],16))

def add_box(slide, x, y, w, h, text,
            fill='#FFFFFF', border='#999999',
            font_size=11, bold=False, text_color='#000000',
            shape_type='rect'):
    from pptx.util import Emu
    from pptx.enum.shapes import MSO_SHAPE_TYPE
    import pptx.shapes.autoshape as AS

    txBox = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = txBox.text_frame
    tf.word_wrap = True

    # background & border via fill/line on the shape
    txBox.fill.solid()
    txBox.fill.fore_color.rgb = rgb(fill)
    txBox.line.color.rgb = rgb(border)
    txBox.line.width = Pt(1)

    tf.margin_left   = Pt(6)
    tf.margin_right  = Pt(6)
    tf.margin_top    = Pt(4)
    tf.margin_bottom = Pt(4)

    for i, line in enumerate(text.split('\n')):
        if i == 0:
            p = tf.paragraphs[0]
        else:
            p = tf.add_paragraph()
        p.alignment = PP_ALIGN.CENTER
        run = p.add_run()
        run.text = line
        run.font.size = Pt(font_size)
        run.font.bold = bold
        run.font.color.rgb = rgb(text_color)

    return txBox

def add_arrow(slide, x1, y1, x2, y2, color='#555555'):
    from pptx.util import Emu
    from pptx.oxml.ns import qn
    from lxml import etree

    cx = Inches(x2 - x1) if x2 >= x1 else Inches(x1 - x2)
    cy = Inches(y2 - y1) if y2 >= y1 else Inches(y1 - y2)

    left   = Inches(min(x1, x2))
    top    = Inches(min(y1, y2))

    connector = slide.shapes.add_connector(1, Inches(x1), Inches(y1), Inches(x2), Inches(y2))
    connector.line.color.rgb = rgb(color)
    connector.line.width = Pt(1.5)

def add_title_box(slide, x, y, w, h, text):
    add_box(slide, x, y, w, h, text,
            fill='#1F3864', border='#1F3864',
            font_size=14, bold=True, text_color='#FFFFFF')

def add_key_box(slide, x, y, w, h, text):
    add_box(slide, x, y, w, h, text,
            fill='#FF9900', border='#B36B00',
            font_size=10, bold=True, text_color='#000000')

def add_step_box(slide, x, y, w, h, text):
    add_box(slide, x, y, w, h, text,
            fill='#EEF3FB', border='#336699',
            font_size=10, text_color='#1A1A2E')

def add_decision_box(slide, x, y, w, h, text):
    add_box(slide, x, y, w, h, text,
            fill='#D6EAF8', border='#336699',
            font_size=10, bold=True, text_color='#000000')

def add_section_label(slide, x, y, w, h, text):
    add_box(slide, x, y, w, h, text,
            fill='#2E4057', border='#2E4057',
            font_size=12, bold=True, text_color='#FFFFFF')

# ── slide ─────────────────────────────────────────────────────────────────────
slide = prs.slides.add_slide(blank_layout)

# background
bg = slide.shapes.add_textbox(0, 0, prs.slide_width, prs.slide_height)
bg.fill.solid()
bg.fill.fore_color.rgb = rgb('#F7F9FC')
bg.line.fill.background()

# ── MAIN TITLE ────────────────────────────────────────────────────────────────
add_box(slide, 0.3, 0.2, 19.4, 0.7,
        'ZBCRE_FRAMEWORK_TEMPLATE — Complete Process Flow',
        fill='#0D1B2A', border='#0D1B2A',
        font_size=18, bold=True, text_color='#FFFFFF')

# ── LEGEND ────────────────────────────────────────────────────────────────────
add_box(slide, 0.3, 1.05, 2.8, 0.35, 'Standard step',      fill='#EEF3FB', border='#336699', font_size=9)
add_key_box(slide, 3.3, 1.05, 2.8, 0.35, '⬡ Key step')
add_decision_box(slide, 6.3, 1.05, 2.8, 0.35, '◆ Decision')
add_box(slide, 9.3, 1.05, 4.5, 0.35, '→ Flow arrow  |  Orange = critical implementation point',
        fill='#F7F9FC', border='#CCCCCC', font_size=9)

# =============================================================================
# FLOW 1 — PROGRAM STARTUP   (col x≈1..9, y starts at 1.7)
# =============================================================================
COL_A = 1.0
W     = 7.5
add_section_label(slide, COL_A, 1.6, W, 0.4, 'FLOW 1 — PROGRAM STARTUP')

steps_f1 = [
    (1.9,  "Selection screen\nMATNR · VDR_HEAT · VDR_CLNO · VDR_CD", 'step'),
    (2.8,  "START-OF-SELECTION\nCREATE OBJECT LO_FRAME  (ZBCCL_GUI_TEMPLATE)", 'step'),
    (3.7,  "LO_FRAME->SET_DATA_FROM_DB()\nLoads data from database", 'step'),
    (4.6,  "LO_FRAME->GET_ORDER_DATA_FOR_GUI()\nReturns WA_SCREEN_DATA", 'step'),
    (5.5,  "ZBCFM_SET_SCREEN_DATA( WA_SCREEN_DATA )\nCreates O_SCREEN (LCL_SCREEN) in the Function Group", 'step'),
    (6.4,  "SET_ORDER_INPUT( EDI_COILS )          SET_HISTORY_SUMMARY( ALV_COILS )", 'step'),
    (7.3,  "CALL SCREEN 100  →  Main screen", 'step'),
]

prev_y = None
for (y, txt, kind) in steps_f1:
    add_step_box(slide, COL_A, y, W, 0.75, txt)
    if prev_y is not None:
        add_arrow(slide, COL_A + W/2, prev_y + 0.75, COL_A + W/2, y)
    prev_y = y

# =============================================================================
# FLOW 2 — SCREEN DISPLAY   (right column, x≈10..)
# =============================================================================
COL_B = 10.5
WB    = 8.5
add_section_label(slide, COL_B, 1.6, WB, 0.4, 'FLOW 2 — SCREEN DISPLAY  (FG: ZBCFG_FRAMEWORK_TEMPLATE)')

steps_f2 = [
    (1.9,  "Screen 100 — Main screen\nPBO: SET PF-STATUS 'SCREEN_100'  →  Buttons: Save Changes · Cancel", 'step'),
    (2.8,  "CALL SUBSCREEN  →  Screen 0130\nTabstrip with 2 tabs", 'step'),
    (3.7,  "Tab 1 (R_TAB01)  →  Subscreen 0140\nALV 140-1  |  Table: OR_PSPEC_REST  |  Field SELECTED: editable", 'step'),
    (4.6,  "Tab 2 (R_TAB03)  →  Subscreen 0180\nALV 180-1  |  Table: HISTORY_SUMMARY\nHEAT_NO: editable  |  BATCH_NO: hotspot", 'step'),
    (5.6,  "INITIALIZE_ALV '180-1'\nStructure: ZSAST_EDI_COILS_FCAT  |  Table: HISTORY_SUMMARY\nHEAT_NO: EDIT=TRUE  |  BATCH_NO: HOTSPOT=TRUE", 'step'),
    (6.65, "⬡  SET HANDLER HANDLE_HOTSPOT_CLICK_180_1\n      FOR O_ALV_LIST_180_1\nRegisters the event — without this no server roundtrip occurs", 'key'),
]

prev_y = None
for (y, txt, kind) in steps_f2:
    h = 0.85 if kind == 'key' else 0.75
    if kind == 'key':
        add_key_box(slide, COL_B, y, WB, h, txt)
    else:
        add_step_box(slide, COL_B, y, WB, h, txt)
    if prev_y is not None:
        prev_h = 0.85 if prev_kind == 'key' else 0.75
        add_arrow(slide, COL_B + WB/2, prev_y + prev_h, COL_B + WB/2, y)
    prev_y   = y
    prev_kind = kind

# =============================================================================
# FLOW 3 — SAVE CHANGES   (col x≈1, y starts at 8.4)
# =============================================================================
Y3 = 8.6
add_section_label(slide, 0.3, Y3, 19.4, 0.4, 'FLOW 3 — SAVE CHANGES  (button on Screen 100)')

CX   = 1.0
WC   = 8.0
CX2  = 10.5
WC2  = 8.5

# left column
left_steps = [
    (Y3+0.6,  "User edits HEAT_NO field in ALV 180-1", 'step'),
    (Y3+1.45, "User clicks 'Save Changes' button", 'step'),
    (Y3+2.3,  "PAI Screen 100: MODULE USER_COMMAND_0100\nSAVE_OK = 'SAVE'  →  CLEAR OK_CODE", 'step'),
    (Y3+3.15, "LCL_REPORT=>SAVE() is invoked", 'step'),
    (Y3+4.0,  "ZBCFM_GET_SCREEN_DATA() is invoked", 'step'),
    (Y3+4.85, "⬡  O_ALV_LIST_180_1->CHECK_CHANGED_DATA()\nFlushes the last edited cell into HISTORY_SUMMARY\nWithout this call the last edited value is lost", 'key'),
    (Y3+5.85, "⬡  SCREEN_DATA-ALV_COILS = HISTORY_SUMMARY\nIncludes editable ALV data in the return value", 'key'),
    (Y3+6.7,  "SCREEN_DATA-EDI_COILS = GET_ORDER_INPUT()", 'step'),
]

prev_y = None
for (y, txt, kind) in left_steps:
    h = 0.8 if kind == 'key' else 0.7
    if kind == 'key':
        add_key_box(slide, CX, y, WC, h, txt)
    else:
        add_step_box(slide, CX, y, WC, h, txt)
    if prev_y is not None:
        prev_h = 0.8 if prev_k == 'key' else 0.7
        add_arrow(slide, CX + WC/2, prev_y + prev_h, CX + WC/2, y)
    prev_y = y
    prev_k = kind

# decision
DY = Y3 + 7.6
add_decision_box(slide, CX, DY, WC, 0.7, '◆  e_valid = TRUE ?')
add_arrow(slide, CX + WC/2, prev_y + 0.7, CX + WC/2, DY)

# TRUE branch (right column)
right_steps = [
    (DY,      "CREATE OBJECT O_ORDER (ZBCCL_GUI_TEMPLATE)\nif not already instantiated", 'step'),
    (DY+0.9,  "O_ORDER->SET_ORDER_DATA_FROM_GUI( WA_SCREEN_DATA )\n  · MOVE-CORRESPONDING EDI_COILS\n  · ME->ALV_COILS = P_SCREEN_DATA-ALV_COILS", 'step'),
    (DY+1.9,  "O_ORDER->SAVE()  →  UPDATE_DATA_TO_DB()\n  · MODIFY ZSATB_EDI_COILS FROM EDI_COILS", 'step'),
    (DY+2.8,  "⬡  LOOP AT ALV_COILS INTO WA_EDI_COILS\n      MODIFY ZSATB_EDI_COILS FROM WA_EDI_COILS\nPersists each edited ALV row to database", 'key'),
    (DY+3.8,  "COMMIT WORK AND WAIT", 'step'),
    (DY+4.6,  "SET SCREEN 0 / LEAVE SCREEN\nReturns to the previous screen", 'step'),
]

prev_y2 = None
for (y, txt, kind) in right_steps:
    h = 0.8 if kind == 'key' else 0.7
    if kind == 'key':
        add_key_box(slide, CX2, y, WC2, h, txt)
    else:
        add_step_box(slide, CX2, y, WC2, h, txt)
    if prev_y2 is not None:
        prev_h2 = 0.8 if prev_k2 == 'key' else 0.7
        add_arrow(slide, CX2 + WC2/2, prev_y2 + prev_h2, CX2 + WC2/2, y)
    prev_y2 = y
    prev_k2 = kind

# arrow from decision TRUE to right col
add_arrow(slide, CX + WC, DY + 0.35, CX2, DY + 0.35)
add_box(slide, CX + WC + 0.05, DY + 0.05, 0.9, 0.28, 'TRUE', fill='#F7F9FC', border='#CCCCCC', font_size=8)

# FALSE branch
FY = DY + 1.0
add_step_box(slide, CX, FY, WC, 0.6,
             'Validation error displayed\nUser remains on the screen')
add_arrow(slide, CX + WC/2, DY + 0.7, CX + WC/2, FY)
add_box(slide, CX + WC/2 + 0.05, DY + 0.72, 0.9, 0.24, 'FALSE', fill='#F7F9FC', border='#CCCCCC', font_size=8)

# =============================================================================
# FLOW 4 — HOTSPOT CLICK   (y starts after flow 3)
# =============================================================================
Y4 = DY + 5.6
add_section_label(slide, 0.3, Y4, 19.4, 0.4, 'FLOW 4 — HOTSPOT CLICK  (BATCH_NO column in ALV 180-1)')

hsteps = [
    (0.3,  1.0,  Y4+0.6,  "User clicks BATCH_NO link (CSI BatchNo)", 'step'),
    (0.3,  1.0,  Y4+1.45, "CL_GUI_ALV_GRID fires HOTSPOT_CLICK event\n(client-side event)", 'step'),
    (0.3,  1.0,  Y4+2.35, "⬡  SET HANDLER active  →  server roundtrip\nPAI is triggered  |  Without SET HANDLER the event dies on the client\nand /h never activates", 'key'),
    (0.3,  1.0,  Y4+3.35, "HANDLE_HOTSPOT_CLICK_180_1 executes\nCHECK E_COLUMN_ID-FIELDNAME = 'BATCH_NO'", 'step'),
    (0.3,  1.0,  Y4+4.2,  "READ TABLE HISTORY_SUMMARY\nINDEX ES_ROW_NO-ROW_ID  INTO WA_HIST_SUMM", 'step'),
    (0.3,  1.0,  Y4+5.05, "SUBMIT ZBCRE_FRAMEWORK_TEMPLATE\n  WITH MATNR    = WA_HIST_SUMM-MATNR\n  WITH VDR_HEAT = WA_HIST_SUMM-HEAT_NO\n  WITH VDR_CLNO = WA_HIST_SUMM-COIL_NO\n  WITH VDR_CD   = WA_HIST_SUMM-VENDOR_CD\n  AND RETURN", 'step'),
    (0.3,  1.0,  Y4+6.2,  "Program re-executes with the clicked row's data\nAND RETURN → on close, returns to the current screen", 'step'),
]

CX3 = 1.0
WC3 = 18.0
prev_y3 = None
for (_, __, y, txt, kind) in hsteps:
    h = 0.95 if 'SUBMIT' in txt else (0.85 if kind == 'key' else 0.75)
    if kind == 'key':
        add_key_box(slide, CX3, y, WC3, h, txt)
    else:
        add_step_box(slide, CX3, y, WC3, h, txt)
    if prev_y3 is not None:
        prev_h3 = 0.95 if 'SUBMIT' in prev_txt else (0.85 if prev_k3 == 'key' else 0.75)
        add_arrow(slide, CX3 + WC3/2, prev_y3 + prev_h3, CX3 + WC3/2, y)
    prev_y3  = y
    prev_k3  = kind
    prev_txt = txt

# ── save ──────────────────────────────────────────────────────────────────────
out = '/home/user/ABAPCloud/ZBCRE_FRAMEWORK_TEMPLATE_Flow_EN.pptx'
prs.save(out)
print(f'Saved: {out}')
