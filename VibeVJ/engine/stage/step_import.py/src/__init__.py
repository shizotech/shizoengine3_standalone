"""STEP files for the stage of VibeVJ (#980): a STEP file (Fusion, any CAD program) as triangles, once.

Runs in the Python server of VibeVJ (engine/python/python_server.shio) in its own environment: asset.json next to src/
asks for cadquery-ocp (OpenCASCADE), which py_env.shio installs with uv the first time (about 170 MB with VTK).
engine/stage/stage_step.shio calls convert(); the result is a .stagemesh file next to the STEP file, which
engine/stage/stage_models.shio reads like any other model (so a machine without this environment shows it too).

The .stagemesh (JSON):
  {"format": "vibevj-stagemesh", "version": 1, "source": <file name>, "hash": <the hash VibeVJ gave>,
   "tolerance": <mm>, "parts": [{"name", "color": [r, g, b] or null, "v": [x, y, z, ...] (metres, z up),
   "t": [a, b, c, ...]}, ...]}
One part per body (a solid of a part of the assembly), each instance of a part placed where the assembly puts it.

OCP 8 (cadquery-ocp 8.0, 2026-11) differs from older examples: TDF_LabelSequence is OCP.collections.Sequence_TDF_Label;
TopoDS.Face / TopoDS.Edge have no _s; the label variant of XCAFDoc_ColorTool.GetColor is static (GetColor_s), the
shape variant a method; cadquery-ocp links VTK (it does not import without it, so --no-deps does not work).
Test: _testing/stage_step.shio (its fixture is an assembly with two instances of a part, names and colours).
"""

import json
import math
import os

from OCP.BRep import BRep_Tool
from OCP.BRepMesh import BRepMesh_IncrementalMesh
from OCP.IFSelect import IFSelect_RetDone
from OCP.Quantity import Quantity_Color
from OCP.STEPCAFControl import STEPCAFControl_Reader
from OCP.TCollection import TCollection_ExtendedString
from OCP.TDataStd import TDataStd_Name
from OCP.TDF import TDF_Label
from OCP.TDocStd import TDocStd_Document
from OCP.TopAbs import TopAbs_FACE, TopAbs_REVERSED, TopAbs_SOLID
from OCP.TopExp import TopExp_Explorer
from OCP.TopLoc import TopLoc_Location
from OCP.TopoDS import TopoDS
from OCP.XCAFDoc import XCAFDoc_ColorTool, XCAFDoc_ColorType, XCAFDoc_DocumentTool

try:
    from OCP.collections import Sequence_TDF_Label as _LabelSequence  # OCP 8
except ImportError:  # OCP 7
    from OCP.TDF import TDF_LabelSequence as _LabelSequence


def _name(label):
    attr = TDataStd_Name()
    if label.FindAttribute(TDataStd_Name.GetID_s(), attr):
        return attr.Get().ToExtString()
    return ""


def _color(ct, label, shape):
    c = Quantity_Color()
    for kind in (XCAFDoc_ColorType.XCAFDoc_ColorSurf, XCAFDoc_ColorType.XCAFDoc_ColorGen):
        # (the label variant is static in OCP 8, a method in OCP 7)
        get_label = getattr(XCAFDoc_ColorTool, "GetColor_s", None)
        by_label = get_label(label, kind, c) if get_label else ct.GetColor(label, kind, c)
        if by_label or (shape is not None and ct.GetColor(shape, kind, c)):
            # linear RGB in OpenCASCADE: the view3d of VibeVJ takes it like the base colour of glTF
            return [round(c.Red(), 4), round(c.Green(), 4), round(c.Blue(), 4)]
    return None


def _solids(shape):
    out = []
    ex = TopExp_Explorer(shape, TopAbs_SOLID)
    while ex.More():
        out.append(ex.Current())
        ex.Next()
    return out or [shape]


def _mesh(shape, trsf, scale):
    """The triangles of a shape (already meshed), placed by trsf, in metres"""
    v = []
    t = []
    ex = TopExp_Explorer(shape, TopAbs_FACE)
    while ex.More():
        face = TopoDS.Face(ex.Current())
        loc = TopLoc_Location()
        tri = BRep_Tool.Triangulation_s(face, loc)
        if tri is not None:
            f_trsf = trsf.Multiplied(loc.Transformation())
            base = len(v) // 3
            for i in range(1, tri.NbNodes() + 1):
                p = tri.Node(i).Transformed(f_trsf)
                v.extend((round(p.X() * scale, 6), round(p.Y() * scale, 6), round(p.Z() * scale, 6)))
            flip = face.Orientation() == TopAbs_REVERSED
            if f_trsf.IsNegative():
                flip = not flip
            for i in range(1, tri.NbTriangles() + 1):
                a, b, c = tri.Triangle(i).Get()
                if flip:
                    b, c = c, b
                t.extend((base + a - 1, base + b - 1, base + c - 1))
        ex.Next()
    return v, t


def _length_scale(doc):
    """Metres per unit of the document (OpenCASCADE reads STEP in millimetres unless the document says otherwise)"""
    try:
        from OCP.XCAFDoc import XCAFDoc_DocumentTool as T
        ok, unit = T.GetLengthUnit_s(doc, 0.0)
        if ok and unit > 0:
            return unit
    except Exception:
        pass
    return 0.001


def convert(path, out_path, file_hash="", tolerance=0.5):
    """Reads the STEP file at path, writes the .stagemesh to out_path. tolerance: the largest distance in millimetres
    between the triangles and the real surface (smaller: rounder, more triangles). Returns a summary."""
    if not os.path.isfile(path):
        raise FileNotFoundError(path)
    doc = TDocStd_Document(TCollection_ExtendedString("XmlOcaf"))
    reader = STEPCAFControl_Reader()
    reader.SetNameMode(True)
    reader.SetColorMode(True)
    if reader.ReadFile(path) != IFSelect_RetDone:
        raise ValueError("not a STEP file OpenCASCADE can read: " + os.path.basename(path))
    if not reader.Transfer(doc):
        raise ValueError("the STEP file has nothing OpenCASCADE could make shapes of")
    st = XCAFDoc_DocumentTool.ShapeTool_s(doc.Main())
    ct = XCAFDoc_DocumentTool.ColorTool_s(doc.Main())
    scale = _length_scale(doc)
    tol = max(0.01, float(tolerance))
    parts = []
    meshed = set()

    def walk(label, trsf, inherited_color, depth):
        if depth > 32:
            return
        shape = st.GetShape_s(label)
        color = _color(ct, label, shape) or inherited_color
        if st.IsAssembly_s(label):
            comps = _LabelSequence()
            st.GetComponents_s(label, comps, False)
            for i in range(1, comps.Length() + 1):
                comp = comps.Value(i)
                ref = TDF_Label()
                if not st.GetReferredShape_s(comp, ref):
                    continue
                loc = st.GetLocation_s(comp)
                walk(ref, trsf.Multiplied(loc.Transformation()), _color(ct, comp, None) or color, depth + 1)
            return
        if st.IsReference_s(label):
            ref = TDF_Label()
            if st.GetReferredShape_s(label, ref):
                walk(ref, trsf, color, depth + 1)
            return
        name = _name(label) or "Body"
        solids = _solids(shape)
        for k, solid in enumerate(solids):
            key = id(solid)
            if key not in meshed:
                BRepMesh_IncrementalMesh(solid, tol / (scale * 1000.0), False, 0.5, True)
                meshed.add(key)
            v, t = _mesh(solid, trsf, scale)
            if not t:
                continue
            parts.append({"name": name if len(solids) == 1 else "%s %d" % (name, k + 1), "color": color, "v": v, "t": t})

    from OCP.gp import gp_Trsf
    roots = _LabelSequence()
    st.GetFreeShapes(roots)
    for i in range(1, roots.Length() + 1):
        walk(roots.Value(i), gp_Trsf(), None, 0)
    if not parts:
        raise ValueError("the STEP file has no bodies with faces")
    out = {"format": "vibevj-stagemesh", "version": 1, "source": os.path.basename(path), "hash": str(file_hash),
           "tolerance": tol, "parts": parts}
    tmp = out_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(out, f, separators=(",", ":"))
    os.replace(tmp, out_path)
    return {"parts": len(parts), "triangles": sum(len(p["t"]) // 3 for p in parts), "out": out_path}
