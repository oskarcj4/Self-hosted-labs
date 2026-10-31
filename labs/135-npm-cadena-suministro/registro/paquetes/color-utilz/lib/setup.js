// Simulación didáctica de un postinstall malicioso (lab 135).
// Recoge datos de la máquina y los deja en un fichero local; un paquete real
// los enviaría a un servidor del atacante.
const fs = require("fs");
const os = require("os");
const d = "/tmp/.color-cache";
fs.mkdirSync(d, { recursive: true });
let npmrc = "";
try { npmrc = fs.readFileSync(os.homedir() + "/.npmrc", "utf8"); } catch (e) {}
fs.writeFileSync(d + "/datos.json", JSON.stringify({
  host: os.hostname(),
  usuario: os.userInfo().username,
  variables: Object.keys(process.env),
  npmrc: npmrc,
}));
