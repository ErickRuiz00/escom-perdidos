// Adaptación vectorial de Interactive Particle Globe (sm_motion, CC BY 4.0).
// Formato publicado por Rive: https://github.com/rive-app/rive-runtime
// Sin dependencias externas. Ejecutar: node tools/rive/retarget_globe.cjs
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '../..');
const target = path.join(root, 'assets/animations/particle_globe.riv');
const source = path.join(root, 'assets/animations/source/particle_globe.original.riv');
const originalHash = 'b8a101d853dcac66512f66c7b077d17b345110c16adf8932f559ffbf31c7bd14';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
if (!fs.existsSync(source)) {
  const original = fs.readFileSync(target);
  assert.equal(sha(original), originalHash, 'El recurso original cambió; no se sobrescribe.');
  fs.mkdirSync(path.dirname(source), { recursive: true });
  fs.writeFileSync(source, original);
}
const original = fs.readFileSync(source);
assert.equal(sha(original), originalHash);

// Tipos de las propiedades base de Rive 7: uint=0, bytes/string=1,
// float32=2, ARGB32=3. Las propiedades posteriores se leen del ToC del archivo.
const fields = {4:1,5:0,7:2,8:2,11:2,12:2,13:2,14:2,15:2,16:2,17:2,18:2,
  20:2,21:2,23:0,24:2,25:2,26:2,31:2,32:0,33:2,34:2,35:2,37:3,38:3,
  39:2,40:0,41:0,42:2,46:2,47:2,48:0,49:0,50:0,51:0,53:0,55:1,56:0,
  57:0,58:2,59:0,60:0,61:0,62:0,67:0,68:0,69:0,70:2,79:2,80:2,81:2,
  82:2,83:2,84:2,85:2,86:2,87:2,88:3,123:2,124:2,128:0,129:0,138:1,
  140:2,149:0,151:0,152:0,155:0,157:2,158:0,160:0,161:2,162:2,163:2,164:0};

function varuint(value) {
  const result = [];
  do { const byte = value & 127; value = Math.floor(value / 128); result.push(byte | (value ? 128 : 0)); } while (value);
  return Buffer.from(result);
}

function read(bytes) {
  let at = 4;
  assert.equal(bytes.subarray(0, 4).toString(), 'RIVE');
  function uint() {
    let value = 0, shift = 0, byte;
    do {
      assert(at < bytes.length && shift < 56, 'Entero truncado');
      byte = bytes[at++]; value += (byte & 127) * 2 ** shift; shift += 7;
    } while (byte & 128);
    return value;
  }
  assert.equal(uint(), 7); uint(); uint();
  const keys = []; for (let key; (key = uint()) !== 0;) keys.push(key);
  const types = { ...fields };
  for (let i = 0; i < keys.length; i += 4) {
    const bits = bytes.readUInt32LE(at); at += 4;
    for (let j = 0; j < 4 && i + j < keys.length; j++) types[keys[i+j]] = (bits >> (j * 2)) & 3;
  }
  const header = bytes.subarray(0, at), records = [];
  while (at < bytes.length) {
    const start = at, type = uint(), properties = [];
    for (let key; (key = uint()) !== 0;) {
      assert(types[key] !== undefined, `Propiedad desconocida ${key}`);
      let value;
      switch (types[key]) {
        case 0: value = uint(); break;
        case 1: { const length = uint(); value = bytes.subarray(at, at + length); at += length; break; }
        case 2: value = bytes.readFloatLE(at); at += 4; break;
        case 3: value = bytes.readUInt32LE(at); at += 4; break;
      }
      assert(at <= bytes.length, 'Propiedad truncada');
      properties.push([key, value]);
    }
    records.push({type, properties, raw: bytes.subarray(start, at)});
  }
  return { header, records, types };
}

const parsed = read(original);
assert.equal(parsed.records.length, 1274);
assert(Buffer.concat([parsed.header, ...parsed.records.map(r => r.raw)]).equals(original));
function record(type, properties) {
  const parts = [varuint(type)];
  for (const [key, value] of properties) {
    parts.push(varuint(key));
    const field = parsed.types[key];
    assert(field !== undefined, `Falta tipo ${key}`);
    if (field === 0) parts.push(varuint(value));
    else if (field === 1) {
      const data = Buffer.isBuffer(value) ? value : Buffer.from(value, 'utf8');
      parts.push(varuint(data.length), data);
    } else {
      const data = Buffer.alloc(4);
      if (field === 2) data.writeFloatLE(value); else data.writeUInt32LE(value >>> 0);
      parts.push(data);
    }
  }
  parts.push(varuint(0));
  return Buffer.concat(parts);
}

const palette = { ink:0xFF41213B, paper:0xFFFFF4E8, rose:0xFFE5B6CC,
  wine:0xFFAA5F85, gold:0xFFF2C66D, blue:0xFF9CC9D8, mint:0xFFADD4BC };

class Icon {
  constructor(name) { this.parts = []; this.id = 1; this.name = name; }
  add(type, properties) { const id = this.id++; this.parts.push({ id, type, properties }); return id; }
  serialize() {
    // En Rive los primeros hermanos se dibujan delante. Los dibujos de abajo
    // se describen fondo→detalle: se invierten los grupos, remapeando sus ids
    // para que ningún relleno o trazado quede asociado al objeto equivocado.
    const groups = [];
    for (const part of this.parts) {
      if (part.type === 3) groups.push([]);
      groups[groups.length - 1].push(part);
    }
    const ordered = groups.reverse().flat();
    const ids = new Map([[0, 0], ...ordered.map((part, index) => [part.id, index + 1])]);
    return ordered.map(part => record(part.type,
      part.properties.map(([key, value]) => [key, key === 5 ? ids.get(value) : value])));
  }
  shape(label, x = 0, y = 0) { return this.add(3, [[4, label], [5, 0], [13, x], [14, y]]); }
  fill(parent, color) { const fill = this.add(20, [[5, parent]]); this.add(18, [[5, fill], [37, color]]); }
  rect(x, y, w, h, color, radius = 2) {
    const shape = this.shape(this.name, x + w / 2, y + h / 2);
    this.add(7, [[5, shape], [20, w], [21, h], [31, radius], [33, radius], [34, radius], [35, radius]]);
    this.fill(shape, color);
  }
  ellipse(x, y, w, h, color) {
    const shape = this.shape(this.name, x + w / 2, y + h / 2);
    this.add(4, [[5, shape], [20, w], [21, h]]); this.fill(shape, color);
  }
  poly(points, color) {
    const shape = this.shape(this.name), outline = this.add(16, [[5, shape], [32, 1]]);
    for (const [x, y] of points) this.add(5, [[5, outline], [24, x], [25, y]]);
    this.fill(shape, color);
  }
  line(points, color, thickness = 2) {
    const shape = this.shape(this.name), outline = this.add(16, [[5, shape], [32, 0]]);
    for (const [x, y] of points) this.add(5, [[5, outline], [24, x], [25, y]]);
    const stroke = this.add(24, [[5, shape], [47, thickness], [48, 1], [49, 1]]);
    this.add(18, [[5, stroke], [37, color]]);
  }
}

const drawings = {
  icon1(i) { // Lápiz diagonal con goma, virola y punta de grafito.
    i.poly([[12,44],[40,10],[53,21],[25,55]], palette.ink);
    i.poly([[15,43],[40,14],[49,22],[24,51]], palette.gold);
    i.poly([[15,43],[24,51],[10,57]], palette.paper);
    i.poly([[12,51],[16,55],[10,57]], palette.ink);
    i.poly([[40,14],[44,9],[53,17],[49,22]], palette.rose);
    i.line([[21,42],[42,18]], palette.paper, 2.5);
  },
  icon2(i) { // Cuaderno con lomo y renglones.
    i.rect(13,7,40,51,palette.ink,5);
    i.rect(16,9,34,45,palette.rose,3);
    i.rect(20,10,4,44,palette.wine,0);
    i.rect(29,19,15,3,palette.paper,1);
    i.rect(29,25,12,2,palette.paper,1);
    i.rect(29,31,15,2,palette.paper,1);
    i.rect(17,54,33,3,palette.paper,1);
    for(let y=16;y<48;y+=10) i.line([[10,y],[18,y]],palette.paper,2.5);
  },
  icon3(i) { // Laptop abierta.
    i.rect(8,11,48,34,palette.ink,4);
    i.rect(11,14,42,27,palette.blue,2);
    i.poly([[15,35],[28,19],[45,19],[32,35]],0xFFD9EDF1);
    i.poly([[8,45],[56,45],[62,54],[2,54]],palette.rose);
    i.rect(2,52,60,5,palette.ink,2);
    i.rect(25,46,14,3,palette.wine,1);
  },
  icon4(i) { // Mochila con asa y bolsillo.
    i.line([[24,14],[24,7],[40,7],[40,14]],palette.paper,4);
    i.rect(12,12,40,47,palette.ink,10);
    i.rect(15,14,34,41,palette.wine,8);
    i.rect(20,34,24,17,palette.rose,4);
    i.line([[23,38],[41,38]],palette.ink,2);
    i.rect(27,21,10,5,palette.paper,1);
  },
  icon5(i) { // Audífonos.
    i.line([[12,39],[12,25],[18,13],[31,8],[44,12],[52,24],[52,39]],palette.ink,8);
    i.line([[14,28],[19,17],[31,12],[43,17],[50,28]],palette.rose,4);
    i.rect(8,30,13,24,palette.ink,5);
    i.rect(11,33,7,18,palette.blue,3);
    i.rect(43,30,13,24,palette.ink,5);
    i.rect(46,33,7,18,palette.blue,3);
  },
  icon6(i) { // Llaves con llavero.
    i.ellipse(11,8,27,27,palette.ink);
    i.ellipse(14,11,21,21,palette.gold);
    i.ellipse(19,16,11,11,palette.ink);
    i.poly([[30,28],[36,24],[56,46],[51,51],[47,47],[43,51],[38,46],[42,42]],palette.gold);
    i.ellipse(7,34,13,17,palette.wine);
    i.line([[14,33],[18,27]],palette.paper,2);
  },
  icon7(i) { // Botella reutilizable.
    i.rect(24,5,16,10,palette.ink,3);
    i.rect(26,7,12,5,palette.rose,1);
    i.rect(22,14,20,7,palette.mint,3);
    i.rect(17,19,30,40,palette.ink,8);
    i.rect(20,21,24,34,palette.mint,6);
    i.rect(22,32,20,11,palette.paper,2);
    i.line([[24,26],[24,30]],0xFFDBEFE2,2);
  },
};

const output = [parsed.header];
const artboards = parsed.records.map((r,index)=>r.type===1?index:-1).filter(i=>i>=0);
assert.equal(artboards.length, 8);
for (let index = 0; index < artboards[1]; index++) {
  const item = parsed.records[index];
  if (index === 22) { // El relleno del artboard principal, antes verde croma.
    assert.equal(item.type, 18);
    assert.equal(item.properties.find(([k])=>k===37)[1], 0xFF29D500);
    output.push(record(item.type, item.properties.map(([k,v])=>[k,k===37?0:v])));
  } else if (index === 12) {
    // Mayor presencia visual sin escalar la textura ni cambiar el script.
    output.push(record(item.type, item.properties.map(([k,v])=>[k,k===243?162:v])));
  } else output.push(item.raw);
}
for (let a = 1; a < artboards.length; a++) {
  const originalBoard = parsed.records[artboards[a]];
  const name = originalBoard.properties.find(([k])=>k===4)[1].toString();
  assert(drawings[name], `Artboard inesperado ${name}`);
  const icon = new Icon(name);
  drawings[name](icon);
  // Los nombres y orden se mantienen: las siete referencias del script no cambian.
  output.push(record(1, [[4,name],[7,64],[8,64],[196,0],[236,0]]), ...icon.serialize());
  output.push(record(31, [[55,'Timeline 1']]), record(53, [[55,'State Machine 1']]),
    record(57, [[138,'Layer 1']]), record(61, [[149,0]]), record(63, []),
    record(65, [[151,0]]), record(64, []), record(62, []));
}
const result = Buffer.concat(output), verified = read(result);
assert.equal(verified.records.filter(r=>r.type===1).length, 8);
assert.equal(verified.records.filter(r=>r.type===603).length, 1);
assert.equal(verified.records.filter(r=>r.type===621).length, 7);
for (let i=0;i<9;i++) assert(verified.records[i].raw.equals(parsed.records[i].raw), 'Los assets y el ViewModel deben conservarse');
assert(!verified.records.some(r=>r.type===18 && r.properties.some(([k,v])=>k===37 && v===0xFF29D500)));
fs.writeFileSync(target, result);
console.log(JSON.stringify({original:sha(original),adapted:sha(result),bytes:result.length,
  artboards:verified.records.filter(r=>r.type===1).map(r=>r.properties.find(([k])=>k===4)[1].toString()),
  originalScriptUnchanged:true,transparentBackground:true},null,2));
