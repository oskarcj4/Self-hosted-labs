exports.corta = (d) => d.toISOString().slice(0, 10).split("-").reverse().join("/");
