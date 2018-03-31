const fs = require('fs');
const path = require('path');

const contractsPath = path.join(__dirname, '..', 'build', 'contracts');
const libPath = path.join(__dirname, '..', 'lib');
const abisPath = path.join(libPath, 'abis');
const addressesPath = path.join(libPath, 'addresses');

const files = [
  'Contributors',
  'Operator',
  'Registry',
  'Token'
];

files.forEach((fileName) => {
  let file = require(`${contractsPath}/${fileName}.json`);
  let abiFile = path.join(abisPath, `${fileName}.json`);
  fs.writeFileSync(abiFile, JSON.stringify(file.abi));

  let addresseFile = path.join(addressesPath, `${fileName}.json`);
  let addresses = Object.keys(file.networks)
    .reduce((addresses, key) => {
      addresses[key] = file.networks[key].address;
      return addresses;
    }, {});
  fs.writeFileSync(addresseFile, JSON.stringify(addresses));

  let indexFile = path.join(libPath, 'index.js');
  fs.writeFileSync(indexFile, `module.exports = ${JSON.stringify(files)};`);
});
