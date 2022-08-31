import tensorflow as tf
hello = tf.constant('Hello, TensorFlow!')
a = tf.constant(10)
b = tf.constant(32)
tf.debugging.assert_equal(a+b, 42)
print(a+b)
print("a+b={}".format(a+b))
print("Test finished")