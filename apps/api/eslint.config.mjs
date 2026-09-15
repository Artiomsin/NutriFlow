import eslint from '@eslint/js';
import tsParser from '@typescript-eslint/parser';
import tsPlugin from '@typescript-eslint/eslint-plugin';
import eslintPluginPrettierRecommended from 'eslint-plugin-prettier/recommended';
import globals from 'globals';

const baseTsConfig = {
  languageOptions: {
    parser: tsParser,
    globals: {
      ...globals.node,
    },
    sourceType: 'module',
  },
  plugins: {
    '@typescript-eslint': tsPlugin,
  },
  rules: {
    '@typescript-eslint/no-explicit-any': 'off',
    'no-unused-vars': 'off',
    '@typescript-eslint/no-unused-vars': 'warn',
  },
};

export default [
  eslint.configs.recommended,

  {
    files: ['**/*.ts'],
    ignores: ['**/*.spec.ts', '**/*.test.ts'],
    ...baseTsConfig,
    languageOptions: {
      ...baseTsConfig.languageOptions,
      parserOptions: {
        projectService: true,
      },
    },
    rules: {
      ...baseTsConfig.rules,
      '@typescript-eslint/no-floating-promises': 'warn',
      '@typescript-eslint/no-unsafe-argument': 'warn',
    },
  },

  {
    files: ['**/*.spec.ts', '**/*.test.ts'],
    ...baseTsConfig,
    languageOptions: {
      ...baseTsConfig.languageOptions,
      globals: {
        ...globals.node,
        ...globals.jest,
      },
    },
  },

  eslintPluginPrettierRecommended,
];