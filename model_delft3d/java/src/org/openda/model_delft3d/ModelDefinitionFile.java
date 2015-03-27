package org.openda.model_delft3d;

import java.io.File;
import java.io.IOException;
import java.io.FileReader;
import java.io.BufferedReader;

/**
 * Mdf File reader (and future writer?), stores the relevant information of the D3D-flow mdf-file
 */
public class ModelDefinitionFile {

    protected static ModelDefinitionFile lastModelDefinitionFile = null;

    public static final String DEPTH = "dep";
    public static final String ROUGHNESS = "rgh";
    public static final String BOUNDARY = "bnd";
    public static final String BC_ASTRONOMIC = "ana";
    public static final String BC_ASTRO_CORR = "cor";
	public static final String WINDU = "wu";     // wind file on equidistant grid (keyword filwu) //TODO
	public static final String WINDV = "wv";     // wind file on equidistant grid (keyword filwv) //TODO
	public static final String WINDGU = "gu";     // wind file with separate curvilinear grid file (keyword fwndgu)
	public static final String WINDGV = "gv";     // wind file with separate curvilinear grid file (keyword fwndgv)

    public static final String[] fileKeys = {DEPTH, ROUGHNESS, BOUNDARY, BC_ASTRONOMIC, BC_ASTRO_CORR, WINDGU, WINDGV};

    private String[] fileNames = null;
    private String[] formats = null;

    private File mdFile;
    private int mMax;
    private int nMax;
    private int kMax;

    public static void checkD3dFileArguments(String fileKey, String[] knownFileTypes) {
        boolean knownArgument = false;
        for (String knownType : knownFileTypes) {
            if (knownType.equalsIgnoreCase(fileKey)) {
                knownArgument = true;
                break;
            }
        }
        if (!knownArgument) {
            throw new RuntimeException("Unknown argument: \"" + fileKey + "\"\nExpected: "
                    + ModelDefinitionFile.getKnownFileTypesString(knownFileTypes));
        }
    }

    public static ModelDefinitionFile getModelDefinitionFile(File workingDir, String mdFileName) {
        if (mdFileName == null || mdFileName.length() == 0) {
            throw new IllegalArgumentException("mdf-file not provided");
        }
        File mdFile = new File(workingDir, mdFileName);
        if (!mdFile.exists()) {
            throw new RuntimeException("mdf-mdFile does not exist: " + mdFile.getAbsolutePath());
        }
        ModelDefinitionFile modelDefinitionFile;
        if (ModelDefinitionFile.lastModelDefinitionFile != null && mdFile.equals(ModelDefinitionFile.lastModelDefinitionFile.getMdFile())) {
            modelDefinitionFile = ModelDefinitionFile.lastModelDefinitionFile;
        } else {
            modelDefinitionFile = new ModelDefinitionFile(mdFile);
        }
        return modelDefinitionFile;
    }

    public ModelDefinitionFile(File mdFile) {

        fileNames = new String[fileKeys.length];
        formats = new String[fileKeys.length];
        for (int i = 0; i < fileKeys.length; i++) {
            fileNames[i] = null;
            formats[i] = null;
        }

        try {
            BufferedReader inputFileBufferedReader = new BufferedReader(new FileReader(mdFile));
            String line = inputFileBufferedReader.readLine();
            while (line != null) {
                String[] fields = line.split("= *");
                if (fields.length == 2) {
                    String key = fields[0].trim();
                    String value = fields[1].trim();
                    if (key.equalsIgnoreCase("mnkmax")) {
                        // m/n/k sizes
                        String[] mnkValues = value.split("[\t ]+");
                        if (mnkValues.length != 3) {
                            throw new RuntimeException("Invalid MNKmax line\n\t" + line + "\nin mdf mdFile" + mdFile.getAbsolutePath());
                        }
                        mMax = Integer.parseInt(mnkValues[0]);
                        nMax = Integer.parseInt(mnkValues[1]);
                        kMax = Integer.parseInt(mnkValues[2]);
                    } else if (value.startsWith("#")) {
                        // mdFile name specification
                        String[] valueStrings = value.substring(1).split("#");
                        if (valueStrings.length == 1) {
                            for (int i = 0; i < fileKeys.length; i++) {
                                if (key.equalsIgnoreCase("fil" + fileKeys[i]) || key.equalsIgnoreCase("fwnd" + fileKeys[i])) {
                                    fileNames[i] = valueStrings[0].trim();
                                } else if (key.equalsIgnoreCase("fmt" + fileKeys[i])) {
                                    formats[i] = valueStrings[0].trim();
                                }
                            }
                        }
                    }
                }
                line = inputFileBufferedReader.readLine();
            }
            inputFileBufferedReader.close();
        } catch (IOException e) {
            throw new RuntimeException("Could not read from " + mdFile.getAbsolutePath());
        }

        this.mdFile = mdFile;
        synchronized (this) {
            lastModelDefinitionFile = this;
        }
    }

    public String[] getFileKeys() {
        return fileKeys;
    }

    public String[] getFileNames() {
        return fileNames;
    }

    public String[] getFormats() {
        return formats;
    }

    public static String getKnownFileTypesString(String[] fileTypes) {
        String result = "";
        for (int i = 0; i < fileTypes.length; i++) {
            if (i > 0) result += ", ";
            result += fileTypes[i];
        }
        return result;
    }

    public File getMdFile() {
        return mdFile;
    }

    public File getFieldFile(String fileKey, boolean mustExist) {
        int fileTypeIndex = findFileTypeIndex(fileKey);
        String fileName = fileNames[fileTypeIndex];
        if (fileName == null || fileName.length() == 0) {
            if (mustExist) {
                throw new RuntimeException(fileKey +
                        " file not specified in model definition file " + mdFile.getAbsolutePath());
            }
            return null;
        }
        return new File(mdFile.getParentFile(), fileName);
    }

    private int findFileTypeIndex(String fileKey) {
        for (int i = 0; i < fileKeys.length; i++) {
            String knownFileKey = fileKeys[i];
            if (knownFileKey.equalsIgnoreCase(fileKey)) {
                return i;
            }
        }
        throw new RuntimeException("Unknown file key type: \"" + fileKey + "\"");
    }

    public int getMmax() {
        return mMax;
    }

    public int getNmax() {
        return nMax;
    }

    public int getKmax() {
        return kMax;
    }
}