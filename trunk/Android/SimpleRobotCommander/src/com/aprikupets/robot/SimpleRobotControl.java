/*
 *
 * Copyright (C) 2012 Andrey Prikupets
 * Copyright (C) 2011 Eirik Taylor
 *
 * This work is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 3.0 Unported License.
 * See the following website for more information: 
 * http://creativecommons.org/licenses/by-nc-sa/3.0/
 * 
 */

package com.aprikupets.robot;

import java.io.IOException;
import java.io.OutputStream;
import java.util.List;
import java.util.UUID;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothSocket;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.DialogInterface.OnClickListener;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.view.*;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

public class SimpleRobotControl extends Activity {

    public interface RobotCommands {
        String COMMAND_PREFIX = ">";
        String COMMAND_SUFFIX = "\n";
        String ROBOT_RESET = COMMAND_PREFIX + "R" + COMMAND_SUFFIX;
        String AVOIDANCE_ENABLED = COMMAND_PREFIX + "A1" + COMMAND_SUFFIX;
        String AVOIDANCE_DISABLED = COMMAND_PREFIX + "A0" + COMMAND_SUFFIX;
        String STOP = COMMAND_PREFIX + "S" + COMMAND_SUFFIX;
        String TRANSPORT = COMMAND_PREFIX + "T%03d,%03d" + COMMAND_SUFFIX;
        String NO_DEBUG = COMMAND_PREFIX + "N" + COMMAND_SUFFIX;
        int ZERO_SPEED = 500;
    }

    // Intent request codes
    private static final int REQUEST_CONNECT_DEVICE = 1;
    private static final int REQUEST_ENABLE_BT = 2;

    // Program variables
    private boolean avoidanceEnabled;
    private boolean connectStat = false;
    private Button avoidance_button;
    private Button command_button;
    private Button stop_button;
    private Button connect_button;
    private TextView accel;
    private AlertDialog aboutAlert;
    private View aboutView;
    private View controlView;
    OnClickListener myClickListener;
    ProgressDialog myProgressDialog;
    private Toast failToast;
    private Handler mHandler;

    // Sensor object used to handle accelerometer
    private SensorManager mySensorManager;
    private List<Sensor> sensors;
    private Sensor accSensor;

    // Bluetooth Stuff
    private BluetoothAdapter mBluetoothAdapter = null;
    private BluetoothSocket btSocket = null;
    private OutputStream outStream = null;
    private ConnectThread mConnectThread = null;
    private String deviceAddress = null;
    // Well known SPP UUID (will *probably* map to RFCOMM channel 1 (default) if not in use); 
    private static final UUID SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");

    /**
     * Called when the activity is first created.
     */
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Create main button view
        LayoutInflater inflater = (LayoutInflater) getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        aboutView = inflater.inflate(R.layout.aboutview, null);
        controlView = inflater.inflate(R.layout.main, null);
        controlView.setKeepScreenOn(true);
        setContentView(controlView);

        // Finds buttons in .xml layout file
        avoidance_button = (Button) findViewById(R.id.avoidance_button);
        command_button = (Button) findViewById(R.id.command_button);
        stop_button = (Button) findViewById(R.id.stop_button);
        connect_button = (Button) findViewById(R.id.connect_button);
        accel = (TextView) findViewById(R.id.accText);

        // Set Sensor
        mySensorManager = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
        sensors = mySensorManager.getSensorList(Sensor.TYPE_ACCELEROMETER);
        if (sensors.size() > 0) {
            accSensor = sensors.get(0);
        } else {
            Toast.makeText(this, R.string.no_acc, Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        // Handle click events from help and info dialogs
        myClickListener = new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int which) {
                switch (which) {
                    case DialogInterface.BUTTON_POSITIVE:
                        dialog.dismiss();
                        break;
                    case DialogInterface.BUTTON_NEUTRAL:
                        // Display website
                        Intent browserIntent = new Intent("android.intent.action.VIEW", Uri.parse(getResources().getString(R.string.website_url)));
                        startActivity(browserIntent);
                        break;
                    default:
                        dialog.dismiss();
                }
            }
        };

        myProgressDialog = new ProgressDialog(this);
        failToast = Toast.makeText(this, R.string.failedToConnect, Toast.LENGTH_SHORT);

        mHandler = new Handler() {
            @Override
            public void handleMessage(Message msg) {
                if (myProgressDialog.isShowing()) {
                    myProgressDialog.dismiss();
                }

                // Check if bluetooth connection was made to selected device
                if (msg.what == 1) {
                    // Set button to display current status
                    connectStat = true;
                    connect_button.setText(R.string.connected);

                    // Reset the BluCar
                    avoidanceEnabled = false;
                    write(RobotCommands.ROBOT_RESET); // Reset
                    try {
                        Thread.sleep(1000);
                    } catch (InterruptedException e) {}
                    write(RobotCommands.NO_DEBUG); // Reset
                } else {
                    // Connection failed
                    failToast.show();
                }
            }
        };

        // Create about dialog
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setView(aboutView).setCancelable(true).
                setTitle(getResources().getString(R.string.app_name) + " " + getResources().getString(R.string.appVersion)).
                setIcon(R.drawable.simple_robot_control_icon).
                setPositiveButton(getResources().getString(R.string.okButton), myClickListener).
                setNeutralButton(getResources().getString(R.string.websiteButton), myClickListener);
        aboutAlert = builder.create();

        // Check whether bluetooth adapter exists
        mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        if (mBluetoothAdapter == null) {
            Toast.makeText(this, R.string.no_bt_device, Toast.LENGTH_LONG).show();
            connect_button.setText(R.string.disconnected);
//            finish();
            return;
        }

        // If BT is not on, request that it be enabled.
        if (mBluetoothAdapter != null && !mBluetoothAdapter.isEnabled()) {
            Intent enableIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
            startActivityForResult(enableIntent, REQUEST_ENABLE_BT);
        }

        /**********************************************************************
         * Buttons for controlling Robot
         */

        // Connect to Bluetooth Module
        if (mBluetoothAdapter != null) {
            connect_button.setOnClickListener(new View.OnClickListener() {

                public void onClick(View v) {
                    if (connectStat) {
                        // Attempt to disconnect from the device
                        disconnect();
                    } else {
                        // Attempt to connect to the device
                        connect();
                    }
                }
            });
        } else {
            connect_button.setEnabled(false);
        }

        // Toggle Avoidance;
        avoidance_button.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                if (avoidanceEnabled) {
                    avoidance_button.setText(R.string.avoidance_disabled);
                    avoidanceEnabled = false;
                    write(RobotCommands.AVOIDANCE_DISABLED);
                } else {
                    avoidance_button.setText(R.string.avoidance_enabled);
                    avoidanceEnabled = true;
                    write(RobotCommands.AVOIDANCE_ENABLED);
                }
            }
        });

        // Drive forward
        command_button.setOnTouchListener(new View.OnTouchListener() {

            public boolean onTouch(View v, MotionEvent event) {
                if ((event.getAction() == MotionEvent.ACTION_DOWN) | (event.getAction() == MotionEvent.ACTION_MOVE)) {
                    if (!command_button.isPressed()) {
                        command_button.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY);
                        command_button.setPressed(true);
                    }
                    return true;

                } else if (event.getAction() == MotionEvent.ACTION_UP) {
                    command_button.setPressed(false);
                    return true;
                }
                command_button.setPressed(false);
                return false;
            }
        });

        // Back up
        stop_button.setOnTouchListener(new View.OnTouchListener() {

            public boolean onTouch(View v, MotionEvent event) {
                if ((event.getAction() == MotionEvent.ACTION_DOWN) | (event.getAction() == MotionEvent.ACTION_MOVE)) {
                    if (!stop_button.isPressed()) {
                        stop_button.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY);
                        stop_button.setPressed(true);
                    }
                    write(RobotCommands.STOP);
                    return true;

                } else if (event.getAction() == MotionEvent.ACTION_UP) {
                    stop_button.setPressed(false);
                    return true;
                }
                stop_button.setPressed(false);
                return false;
            }
        });

    }

    /**
     * Thread used to connect to a specified Bluetooth Device
     */
    public class ConnectThread extends Thread {
        private String address;
        private boolean connectionStatus;

        ConnectThread(String MACaddress) {
            address = MACaddress;
            connectionStatus = true;
        }

        public void run() {
            // When this returns, it will 'know' about the server,
            // via it's MAC address. 
            try {
                BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(address);

                // We need two things before we can successfully connect
                // (authentication issues aside): a MAC address, which we
                // already have, and an RFCOMM channel.
                // Because RFCOMM channels (aka ports) are limited in
                // number, Android doesn't allow you to use them directly;
                // instead you request a RFCOMM mapping based on a service
                // ID. In our case, we will use the well-known SPP Service
                // ID. This ID is in UUID (GUID to you Microsofties)
                // format. Given the UUID, Android will handle the
                // mapping for you. Generally, this will return RFCOMM 1,
                // but not always; it depends what other BlueTooth services
                // are in use on your Android device.
                try {
                    btSocket = device.createRfcommSocketToServiceRecord(SPP_UUID);
                    // Method m = device.getClass().getMethod("createRfcommSocket",
                    //            new Class[] { int.class });
                    // btSocket = (BluetoothSocket)m.invoke(device, Integer.valueOf(1));
                } catch (Exception e) {
                    // Toast.makeText(SimpleRobotControl.this, e.getMessage(), Toast.LENGTH_SHORT).show();
                    connectionStatus = false;
                }
            } catch (IllegalArgumentException e) {
                connectionStatus = false;
            }

            // Discovery may be going on, e.g., if you're running a 
            // 'scan for devices' search from your handset's Bluetooth 
            // settings, so we call cancelDiscovery(). It doesn't hurt 
            // to call it, but it might hurt not to... discovery is a 
            // heavyweight process; you don't want it in progress when 
            // a connection attempt is made. 
            mBluetoothAdapter.cancelDiscovery();

            // Blocking connect, for a simple client nothing else can 
            // happen until a successful connection is made, so we 
            // don't care if it blocks.
            if (connectionStatus) {
                try {
                    btSocket.connect();
                } catch (IOException e1) {
                    try {
                        btSocket.close();
                    } catch (IOException e2) {
                    }
                    connectionStatus = false;
                }
            }

            // Create a data stream so we can talk to server.
            if (connectionStatus) {
                try {
                    outStream = btSocket.getOutputStream();
                } catch (IOException e2) {
                    connectionStatus = false;
                }
            }

            // Send final result
            if (connectionStatus) {
                mHandler.sendEmptyMessage(1);
            } else {
                mHandler.sendEmptyMessage(0);
            }
        }
    }

    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        switch (requestCode) {
            case REQUEST_CONNECT_DEVICE:
                // When DeviceListActivity returns with a device to connect
                if (resultCode == Activity.RESULT_OK) {
                    // Show please wait dialog
                    myProgressDialog = ProgressDialog.show(this, getResources().getString(R.string.pleaseWait), getResources().getString(R.string.makingConnectionString), true);

                    // Get the device MAC address
                    deviceAddress = data.getExtras().getString(DeviceListActivity.EXTRA_DEVICE_ADDRESS);
                    // Connect to device with specified MAC address
                    mConnectThread = new ConnectThread(deviceAddress);
                    mConnectThread.start();

                } else {
                    // Failure retrieving MAC address
                    Toast.makeText(this, R.string.macFailed, Toast.LENGTH_SHORT).show();
                }
                break;
            case REQUEST_ENABLE_BT:
                // When the request to enable Bluetooth returns
                if (resultCode == Activity.RESULT_OK) {
                    // Bluetooth is now enabled
                } else {
                    // User did not enable Bluetooth or an error occured
                    Toast.makeText(this, R.string.bt_not_enabled_leaving, Toast.LENGTH_SHORT).show();
                    finish();
                }
        }
    }

    public void write(String data) {
        if (outStream != null) {
            try {
                outStream.write(data.getBytes("US-ASCII"));
                outStream.flush();
            } catch (IOException e) {
                Toast.makeText(this, "Exception: " + e.getMessage(), Toast.LENGTH_SHORT).show();
            }
        }
    }

    public void emptyOutStream() {
        if (outStream != null) {
            try {
                outStream.flush();
            } catch (IOException e) {
                Toast.makeText(this, "Exception: " + e.getMessage(), Toast.LENGTH_SHORT).show();
            }
        }
    }

    public void connect() {
        // Launch the DeviceListActivity to see devices and do scan
        Intent serverIntent = new Intent(this, DeviceListActivity.class);
        startActivityForResult(serverIntent, REQUEST_CONNECT_DEVICE);
    }

    public void disconnect() {
        if (outStream != null) {
            try {
                outStream.close();
                connectStat = false;
                connect_button.setText(R.string.disconnected);
            } catch (IOException e) {
            }
        }
    }

    private final SensorEventListener mSensorListener = new SensorEventListener() {

        protected static final int MOVE_TIME = 250;
        private long lastWrite = 0;

        public void onAccuracyChanged(Sensor sensor, int accuracy) {
        }

        protected int accToDeg(float acc) {
            double arcsin = acc / SensorManager.GRAVITY_EARTH;
            // clipping the sensor output;
            if (arcsin < -1.0)
                arcsin = -1.0;
            else if (arcsin > 1.0)
                arcsin = 1.0;
            double angle = Math.toDegrees(Math.asin(arcsin));
            // clipping the angle;
            if (angle < -MAX_ANGLE)
                angle = -MAX_ANGLE;
            else if (angle > MAX_ANGLE)
                angle = MAX_ANGLE;
            return (int) Math.round(angle);
        }

        public final static int MIN_PWM = 90; // Empirically given for particular Robot;
        public final static int MAX_PWM = 255;
        public final static int MAX_SPEED = MAX_PWM - MIN_PWM; // Speed is in range -MAX_SPEED..0..MAX_SPEED;

        protected float degToSpeed(int angle) {
            return ((float) angle) * MAX_SPEED / (MAX_ANGLE - MIN_ANGLE);
        }

        public final static int MIN_ANGLE = 5;
        public final static int MAX_ANGLE = 70;

        // low-pass filtering parameters;
        protected final static float ALPHA = 0.5f;
        protected float gravity[] = {0, 0};
        protected float linear_acceleration[] = {0, 0};

        // speed;
        protected int last_speed[] = {0, 0};
        protected int speed[] = new int[2];

        // filtering out small changes in speed;
        public final static int NOISE_SPEED = 10;

        public void onSensorChanged(SensorEvent event) {
            // Checks whether to send steering command or not
 			long date = System.currentTimeMillis();
 			if (date - lastWrite < MOVE_TIME)
                 return;

            lastWrite = date;

            // Perform some low-pass filtering to separate gravity vector of acceleration;
            // ALPHA is calculated as t / (t + dT)
            // with t, the low-pass filter's time-constant
            // and dT, the event delivery rate
            gravity[0] = ALPHA * gravity[0] + (1 - ALPHA) * event.values[0];
            gravity[1] = ALPHA * gravity[1] + (1 - ALPHA) * event.values[1];
            linear_acceleration[0] = event.values[0] - gravity[0];
            linear_acceleration[1] = event.values[1] - gravity[1];

            int angleX = accToDeg(gravity[0]);
            int angleY = accToDeg(gravity[1]);
            if (angleX > MIN_ANGLE) {
                // Turn left
                angleX -= MIN_ANGLE;
            } else if (angleX < -MIN_ANGLE) {
                // Turn right
                angleX += MIN_ANGLE;
            } else {
                angleX = 0;
            }

            if (angleY > MIN_ANGLE) {
                // Turn backward;
                angleY -= MIN_ANGLE;
            } else if (angleY < -MIN_ANGLE) {
                // Turn forward;
                angleY += MIN_ANGLE;
            } else {
                // Still or rotate;
                angleY = 0;
            }

            // Make wheels speed from angles;
            int speed[] = new int[2];
            float forwardSpeed = -degToSpeed(angleY);
            float rightSpeed = degToSpeed(angleX);
            speed[0] = Math.round(forwardSpeed - rightSpeed);
            speed[1] = Math.round(forwardSpeed + rightSpeed);

            if ((Math.abs(speed[0]) > MAX_SPEED) ||
                (Math.abs(speed[1]) > MAX_SPEED)) {
                // If some of the speeds gets too big, decrease both proportionally;
                float ratio = ((float) MAX_SPEED) / ((float) Math.max(Math.abs(speed[0]), Math.abs(speed[1])));
                speed[0] = Math.round(speed[0] * ratio);
                speed[1] = Math.round(speed[1] * ratio);
            }

            accel.setText(String.format(getResources().getString(R.string.accFormatXY),
                    gravity[0], gravity[1], angleX, angleY, speed[0], speed[1]));

            if (command_button.isPressed()) { // If command button is pressed, send the update;
                if (Math.abs(last_speed[0] - speed[0]) > NOISE_SPEED ||
                    Math.abs(last_speed[1] - speed[1]) > NOISE_SPEED) {
                    last_speed[0] = speed[0];
                    last_speed[1] = speed[1];
                    write(String.format(RobotCommands.TRANSPORT, RobotCommands.ZERO_SPEED + speed[0], RobotCommands.ZERO_SPEED + speed[1]));
                }
            }
        }
    };

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater = getMenuInflater();
        inflater.inflate(R.menu.option_menu, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case R.id.about:
                // Show info about the author (that's me!)
                aboutAlert.show();
                return true;
        }
        return false;
    }

    @Override
    public void onResume() {
        super.onResume();
        mySensorManager.registerListener(mSensorListener, accSensor, SensorManager.SENSOR_DELAY_GAME);
    }

    @Override
    public void onDestroy() {
        emptyOutStream();
        disconnect();
        if (mSensorListener != null) {
            mySensorManager.unregisterListener(mSensorListener);
        }
        super.onDestroy();
    }
}