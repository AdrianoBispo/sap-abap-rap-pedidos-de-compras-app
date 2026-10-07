import fioriTools from '@sap-ux/eslint-plugin-fiori-tools';

export default [
    // mock server contributors (Node modules, not UI5 code)
    { ignores: ['webapp/localService/**'] },
    ...fioriTools.configs.recommended
];
