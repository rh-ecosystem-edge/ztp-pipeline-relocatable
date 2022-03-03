import {
  addIpDots,
  domainValidator,
  ipTripletAddressValidator,
  ipWithoutDots,
  usernameValidator,
} from './utils';

const TWELVE_SPACES = '            ';
const STRING_SUCCESS = '';
const STRING_FAILED_DOMAIN = "Valid domain wasn't provided";
const STRING_FAILED_USERNAME = "Valid username wasn't provided";

const IP_TRIPLET_SUCCESS = {
  valid: true,
  triplets: ['success', 'success', 'success', 'success'],
};
const IP_TRIPLET_DEFAULT0 = {
  valid: false,
  triplets: ['default', 'success', 'success', 'success'],
};
const IP_TRIPLET_DEFAULT1 = {
  valid: false,
  triplets: ['success', 'default', 'success', 'success'],
};
const IP_TRIPLET_DEFAULT3 = {
  valid: false,
  triplets: ['success', 'success', 'success', 'default'],
};
const IP_TRIPLET_DEFAULT = {
  valid: false,
  triplets: ['default', 'default', 'default', 'default'],
};

describe('Test component utils', () => {
  it('addIpDots', () => {
    expect(() => addIpDots('')).toThrow('Invalid address: ');
    expect(addIpDots('127  1  1  1')).toBe('127.  1.  1.  1');
    expect(addIpDots('127001001001')).toBe('127.001.001.001');
  });

  it('ipWithoutDots', () => {
    expect(ipWithoutDots('127.0.0.1')).toBe('127  0  0  1');
    expect(ipWithoutDots('')).toBe(TWELVE_SPACES);
    expect(ipWithoutDots('127.0.01')).toBe(TWELVE_SPACES);
    expect(ipWithoutDots('127.0.0.1.1')).toBe(TWELVE_SPACES);
  });

  it('Validates IP tripplet', () => {
    expect(ipTripletAddressValidator('127  1  1  1')).toMatchObject(IP_TRIPLET_SUCCESS);
    expect(ipTripletAddressValidator('127001  1001')).toMatchObject(IP_TRIPLET_SUCCESS);
    expect(ipTripletAddressValidator('127001  1')).toMatchObject(IP_TRIPLET_DEFAULT3);
    expect(ipTripletAddressValidator(TWELVE_SPACES)).toMatchObject(IP_TRIPLET_DEFAULT);
    expect(ipTripletAddressValidator('227  1  1  1')).toMatchObject(IP_TRIPLET_SUCCESS);
    expect(ipTripletAddressValidator('267  1  1  1')).toMatchObject(IP_TRIPLET_DEFAULT0);
    expect(ipTripletAddressValidator('167  1  1  1')).toMatchObject(IP_TRIPLET_SUCCESS);
    expect(ipTripletAddressValidator('127255  1  1')).toMatchObject(IP_TRIPLET_SUCCESS);
    expect(ipTripletAddressValidator('127256  1  1')).toMatchObject(IP_TRIPLET_DEFAULT1);
    expect(ipTripletAddressValidator('327  1  1  1')).toMatchObject(IP_TRIPLET_DEFAULT0);
  });

  it('Validates domain', () => {
    expect(domainValidator('')).toBe(STRING_SUCCESS);
    expect(domainValidator('redhat.com')).toBe(STRING_SUCCESS);
    expect(domainValidator('redhat-redhat.com')).toBe(STRING_SUCCESS);
    expect(domainValidator('bar.redhat-redhat.com')).toBe(STRING_SUCCESS);

    expect(domainValidator('redhat')).toBe(STRING_FAILED_DOMAIN);
    expect(domainValidator('redhat.')).toBe(STRING_FAILED_DOMAIN);
    expect(domainValidator('redhat.com/')).toBe(STRING_FAILED_DOMAIN);
    expect(domainValidator('redhat.com/foo')).toBe(STRING_FAILED_DOMAIN);
    expect(domainValidator('redhat com')).toBe(STRING_FAILED_DOMAIN);
    expect(domainValidator('redhat_redhat.com')).toBe(STRING_FAILED_DOMAIN);
    expect(domainValidator('redhat_redhat.com-com')).toBe(STRING_FAILED_DOMAIN);
    expect(domainValidator('redhat-redhat.com/')).toBe(STRING_FAILED_DOMAIN);
  });

  it('Validates username', () => {
    expect(usernameValidator('')).toBe(STRING_SUCCESS);
    expect(usernameValidator('foo')).toBe(STRING_SUCCESS);
    expect(usernameValidator('foo-foo')).toBe(STRING_SUCCESS);
    expect(usernameValidator('foo1')).toBe(STRING_SUCCESS);
    expect(usernameValidator('abcdefghij-abcdefghij-abcdefghij-abcdefghij-abcdefghi')).toBe(
      STRING_SUCCESS,
    );

    expect(usernameValidator('foo foo')).toBe(STRING_FAILED_USERNAME);
    expect(usernameValidator(' foo ')).toBe(STRING_FAILED_USERNAME);
    expect(usernameValidator('1foo')).toBe(STRING_FAILED_USERNAME);
    expect(usernameValidator('foo-')).toBe(STRING_FAILED_USERNAME);
    expect(usernameValidator('-foo')).toBe(STRING_FAILED_USERNAME);
    expect(usernameValidator('abcdefghij-abcdefghij-abcdefghij-abcdefghij-abcdefghij')).toBe(
      'Valid username can not be longer than 54 characters.',
    );
  });
});
