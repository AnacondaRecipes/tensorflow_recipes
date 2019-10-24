import tensorflow as tf

# Test tensorflow
hello = tf.constant('Hello, TensorFlow!')
a = tf.constant(10)
b = tf.constant(32)
a + b

# Test that tensorflow supports GPUs
with tf.device('gpu:0'):
    a = tf.constant(10)
    b = tf.constant(32)
    a + b
