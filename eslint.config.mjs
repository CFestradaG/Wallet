import firebaseRulesPlugin from '@firebase/eslint-plugin-security-rules';

export default [
  {
    ignores: ['dist/**/*', 'node_modules/**/*', 'flutter_wallet_app/**/*']
  },
  firebaseRulesPlugin.configs['flat/recommended']
];
