class Root {
  final XMLBIBLE xMLBIBLE;

  Root({required this.xMLBIBLE});
}

class XMLBIBLE {
  final FieldItem fieldItem;
  final List<BIBLEBOOK> bIBLEBOOK;

  XMLBIBLE({required this.fieldItem, required this.bIBLEBOOK});
}

class BIBLEBOOK {
  final FieldItem2 fieldItem;
  final List<CHAPTER> cHAPTER;

  BIBLEBOOK({required this.fieldItem, required this.cHAPTER});
}

class CHAPTER {
  final FieldItem3 fieldItem;
  final List<VER> vERS;

  CHAPTER({required this.fieldItem, required this.vERS});
}

class VER {
  final String fieldItem;
  final FieldItem4 fieldItem2;

  VER({required this.fieldItem, required this.fieldItem2});
}

class FieldItem4 {
  final String vnumber;

  FieldItem4({required this.vnumber});
}

class FieldItem3 {
  final String cnumber;

  FieldItem3({required this.cnumber});
}

class FieldItem2 {
  final String bnumber;
  final String bname;

  FieldItem2({required this.bnumber, required this.bname});
}

class FieldItem {
  final String xmlnsXsi;
  final String biblename;

  FieldItem({required this.xmlnsXsi, required this.biblename});
}
