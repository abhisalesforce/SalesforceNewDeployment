@isTest
private class HelloWorldTest {
    @isTest
    static void testGreetWithName() {
        String result = HelloWorld.greet('Salesforce');
        System.assertEquals('Hello, Salesforce!', result, 'Should greet with the provided name');
    }

    @isTest
    static void testGreetWithBlankName() {
        String result = HelloWorld.greet('');
        System.assertEquals('Hello, World!', result, 'Should return Hello, World! for blank name');
    }

    @isTest
    static void testGreetWithNullName() {
        String result = HelloWorld.greet(null);
        System.assertEquals('Hello, World!', result, 'Should return Hello, World! for null name');
    }
}
