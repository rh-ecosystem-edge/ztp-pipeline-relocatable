import { pathJoin } from './utils';

describe('Test resource utils', () => {
  it('pathJoin', () => {
    expect(pathJoin('aa', 'bb', ' cc', ' dd ', 'ee')).toBe('aa/bb/cc/dd/ee');
    expect(pathJoin()).toBe('');
    expect(pathJoin('aa')).toBe('aa');
  });
});
