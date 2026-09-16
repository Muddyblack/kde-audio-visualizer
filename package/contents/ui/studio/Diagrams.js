.pragma library

// Layout tile diagrams extracted from docs/index.html (DIAG, 64 × 36 viewBox).
// class f: filled .85 · f2: filled .35 · o: outline .6 · s: accent stroke.
var shapes = {
 "lyrics": [
  { "tag": "rect", "cls": "f2", "x": "8", "y": "3", "width": "42", "height": "3", "rx": "1" },
  { "tag": "rect", "cls": "f2", "x": "8", "y": "11", "width": "48", "height": "3", "rx": "1" },
  { "tag": "rect", "cls": "f", "x": "8", "y": "19", "width": "46", "height": "4", "rx": "1" },
  { "tag": "rect", "cls": "f2", "x": "8", "y": "29", "width": "36", "height": "3", "rx": "1" }
 ],
 "classic": [
  {
   "tag": "rect",
   "cls": "f",
   "x": "4",
   "y": "5",
   "width": "15",
   "height": "15",
   "rx": "3"
  },
  {
   "tag": "rect",
   "cls": "o",
   "x": "4",
   "y": "23",
   "width": "15",
   "height": "7",
   "rx": "3.5"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M24 10q3-4 6 0t6 0 6 0 6 0 6 0"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "24",
   "y": "17",
   "width": "36",
   "height": "1.6",
   "rx": ".8"
  },
  {
   "tag": "rect",
   "cls": "f",
   "x": "24",
   "y": "22",
   "width": "26",
   "height": "3",
   "rx": "1"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "24",
   "y": "28",
   "width": "16",
   "height": "2",
   "rx": "1"
  }
 ],
 "mirrored": [
  {
   "tag": "rect",
   "cls": "f",
   "x": "45",
   "y": "5",
   "width": "15",
   "height": "15",
   "rx": "3"
  },
  {
   "tag": "rect",
   "cls": "o",
   "x": "45",
   "y": "23",
   "width": "15",
   "height": "7",
   "rx": "3.5"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M4 10q3-4 6 0t6 0 6 0 6 0 6 0"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "4",
   "y": "17",
   "width": "36",
   "height": "1.6",
   "rx": ".8"
  },
  {
   "tag": "rect",
   "cls": "f",
   "x": "14",
   "y": "22",
   "width": "26",
   "height": "3",
   "rx": "1"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "24",
   "y": "28",
   "width": "16",
   "height": "2",
   "rx": "1"
  }
 ],
 "inline": [
  {
   "tag": "rect",
   "cls": "f",
   "x": "4",
   "y": "5",
   "width": "24",
   "height": "26",
   "rx": "4"
  },
  {
   "tag": "rect",
   "cls": "f",
   "x": "33",
   "y": "6",
   "width": "22",
   "height": "3",
   "rx": "1"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "33",
   "y": "11",
   "width": "14",
   "height": "2",
   "rx": "1"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M33 19q2.5-4 5 0t5 0 5 0 5 0 5 0"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "33",
   "y": "27",
   "width": "14",
   "height": "1.6",
   "rx": ".8"
  },
  {
   "tag": "rect",
   "cls": "o",
   "x": "49",
   "y": "24.5",
   "width": "11",
   "height": "6",
   "rx": "3"
  }
 ],
 "hero": [
  {
   "tag": "path",
   "cls": "s",
   "d": "M6 11q4-8 8 0t8 0 8 0 8 0 8 0 8 0"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "6",
   "y": "19",
   "width": "52",
   "height": "1.6",
   "rx": ".8"
  },
  {
   "tag": "rect",
   "cls": "f",
   "x": "6",
   "y": "24",
   "width": "8",
   "height": "8",
   "rx": "2"
  },
  {
   "tag": "rect",
   "cls": "f",
   "x": "17",
   "y": "25",
   "width": "20",
   "height": "2.6",
   "rx": "1"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "17",
   "y": "29",
   "width": "12",
   "height": "2",
   "rx": "1"
  },
  {
   "tag": "rect",
   "cls": "o",
   "x": "46",
   "y": "24.5",
   "width": "12",
   "height": "7",
   "rx": "3.5"
  }
 ],
 "stacked": [
  {
   "tag": "rect",
   "cls": "f",
   "x": "14",
   "y": "3",
   "width": "10",
   "height": "10",
   "rx": "2"
  },
  {
   "tag": "rect",
   "cls": "f",
   "x": "27",
   "y": "4",
   "width": "22",
   "height": "3.4",
   "rx": "1"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "27",
   "y": "9.5",
   "width": "14",
   "height": "2",
   "rx": "1"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M14 18q3-4 6 0t6 0 6 0 6 0 6 0"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "14",
   "y": "25",
   "width": "36",
   "height": "1.4",
   "rx": ".7"
  },
  {
   "tag": "rect",
   "cls": "o",
   "x": "26",
   "y": "28.5",
   "width": "12",
   "height": "5.5",
   "rx": "2.75"
  }
 ],
 "strip": [
  {
   "tag": "rect",
   "cls": "o",
   "x": "3",
   "y": "12",
   "width": "58",
   "height": "12",
   "rx": "6"
  },
  {
   "tag": "circle",
   "cls": "f",
   "cx": "10",
   "cy": "18",
   "r": "3.6"
  },
  {
   "tag": "rect",
   "cls": "f",
   "x": "16",
   "y": "15.5",
   "width": "14",
   "height": "2.4",
   "rx": "1"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "16",
   "y": "19.5",
   "width": "9",
   "height": "1.6",
   "rx": ".8"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M33 18h2v-3h2v5h2v-6h2v5h2v-2h2v2h2",
   "stroke_width": "1"
  },
  {
   "tag": "path",
   "cls": "f",
   "d": "m52 16 3 2-3 2z"
  }
 ],
 "pill": [
  {
   "tag": "rect",
   "cls": "f2",
   "x": "1",
   "y": "11",
   "width": "62",
   "height": "14",
   "rx": "3"
  },
  {
   "tag": "rect",
   "cls": "o",
   "x": "14",
   "y": "13.5",
   "width": "36",
   "height": "9",
   "rx": "4.5",
   "opacity": 1.0
  },
  {
   "tag": "rect",
   "cls": "f",
   "x": "16.5",
   "y": "15",
   "width": "6",
   "height": "6",
   "rx": "1.5"
  },
  {
   "tag": "rect",
   "cls": "f",
   "x": "25",
   "y": "16.8",
   "width": "14",
   "height": "2.4",
   "rx": "1"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "41",
   "y": "16.8",
   "width": "6",
   "height": "2.4",
   "rx": "1"
  }
 ],
 "pillicon": [
  {
   "tag": "rect",
   "cls": "f2",
   "x": "1",
   "y": "11",
   "width": "62",
   "height": "14",
   "rx": "3"
  },
  {
   "tag": "circle",
   "cls": "f",
   "cx": "32",
   "cy": "18",
   "r": "4.4"
  },
  {
   "tag": "circle",
   "cls": "",
   "cx": "32",
   "cy": "18",
   "r": "6",
   "fill": "none",
   "stroke": "var(--brand)",
   "stroke_width": "1.2",
   "stroke_dasharray": "24 40"
  }
 ],
 "poster": [
  {
   "tag": "path",
   "cls": "s",
   "d": "M8 27V21M12 27V15M16 27V19M20 27V12M24 27V17M28 27V14M32 27V20M36 27V13M40 27V18M44 27V16M48 27V21M52 27V17M56 27V22",
   "opacity": 0.3,
   "stroke_width": "2.2"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "8",
   "y": "7",
   "width": "20",
   "height": "1.8",
   "rx": ".9"
  },
  {
   "tag": "rect",
   "cls": "f",
   "x": "8",
   "y": "11",
   "width": "42",
   "height": "7",
   "rx": "1.5"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "8",
   "y": "26",
   "width": "34",
   "height": "1.4",
   "rx": ".7"
  },
  {
   "tag": "rect",
   "cls": "f",
   "x": "46",
   "y": "24",
   "width": "10",
   "height": "4.4",
   "rx": "1"
  }
 ],
 "orbit": [
  {
   "tag": "circle",
   "cls": "f",
   "cx": "32",
   "cy": "14",
   "r": "5.5"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M40.0 14.0L42.0 14.0",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M39.4 17.1L42.5 18.4",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M37.7 19.7L41.1 23.1",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M35.1 21.4L36.1 23.9",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M32.0 22.0L32.0 26.1",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M28.9 21.4L28.2 23.2",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M26.3 19.7L23.9 22.1",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M24.6 17.1L20.2 18.9",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M24.0 14.0L21.3 14.0",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M24.6 10.9L20.8 9.4",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M26.3 8.3L24.9 6.9",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M28.9 6.6L27.6 3.5",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M32.0 6.0L32.0 1.2",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M35.1 6.6L36.1 4.1",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M37.7 8.3L40.6 5.4",
   "stroke_width": "1.2"
  },
  {
   "tag": "path",
   "cls": "s",
   "d": "M39.4 10.9L41.2 10.2",
   "stroke_width": "1.2"
  },
  {
   "tag": "rect",
   "cls": "f",
   "x": "24",
   "y": "28",
   "width": "16",
   "height": "2.4",
   "rx": "1"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "27",
   "y": "32",
   "width": "10",
   "height": "1.8",
   "rx": ".9"
  }
 ],
 "compact": [
  {
   "tag": "path",
   "cls": "s",
   "d": "M16 10q2.5-4 5 0t5 0 5 0 5 0 5 0 5 0"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "16",
   "y": "17",
   "width": "32",
   "height": "1.6",
   "rx": ".8"
  },
  {
   "tag": "rect",
   "cls": "f",
   "x": "16",
   "y": "22",
   "width": "22",
   "height": "3",
   "rx": "1"
  },
  {
   "tag": "rect",
   "cls": "f2",
   "x": "16",
   "y": "28",
   "width": "14",
   "height": "2",
   "rx": "1"
  }
 ]
};
