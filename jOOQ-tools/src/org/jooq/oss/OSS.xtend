/**
 * Copyright (c) 2009-2013, Data Geekery GmbH (http://www.datageekery.com)
 * All rights reserved.
 *
 * This work is dual-licensed
 * - under the Apache Software License 2.0 (the "ASL")
 * - under the jOOQ License and Maintenance Agreement (the "jOOQ License")
 * =============================================================================
 * You may choose which license applies to you:
 *
 * - If you're using this work with Open Source databases, you may choose
 *   either ASL or jOOQ License.
 * - If you're using this work with at least one commercial database, you must
 *   choose jOOQ License
 *
 * For more information, please visit http://www.jooq.org/licenses
 *
 * Apache Software License 2.0:
 * -----------------------------------------------------------------------------
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * jOOQ License and Maintenance Agreement:
 * -----------------------------------------------------------------------------
 * Data Geekery grants the Customer the non-exclusive, timely limited and
 * non-transferable license to install and use the Software under the terms of
 * the jOOQ License and Maintenance Agreement.
 *
 * This library is distributed with a LIMITED WARRANTY. See the jOOQ License
 * and Maintenance Agreement for more details: http://www.jooq.org/eula
 */
package org.jooq.oss

import static java.util.regex.Pattern.*;

import java.io.File
import java.util.ArrayList
import java.util.regex.Pattern
import org.apache.commons.lang3.tuple.ImmutablePair
import org.jooq.SQLDialect
import org.jooq.xtend.Generators
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class OSS extends Generators {
    
    static ExecutorService ex;
    
    def static void main(String[] args) {
        ex = Executors::newFixedThreadPool(4);
        
        val oss = new OSS();
        
        val workspaceIn = new File("../..").canonicalFile;
        val workspaceOut = new File(workspaceIn.canonicalPath + "/../workspace-jooq-oss").canonicalFile;
        
        for (project : workspaceIn.listFiles[f | f.name.startsWith("jOOQ")]) {
            val in = new File(workspaceIn, project.name);
            val out = new File(workspaceOut, project.name);
            oss.transform(in, out, in);
        }
        
        ex.shutdown;
    }

    def transform(File inRoot, File outRoot, File in) {
        val out = new File(outRoot.canonicalPath + "/" + in.canonicalPath.replace(inRoot.canonicalPath, ""));
        
        if (in.directory) {
            val files = in.listFiles[path | 
                   !path.canonicalPath.endsWith(".class") 
                && !path.canonicalPath.endsWith(".dat")
                && !path.canonicalPath.endsWith(".git")
                && !path.canonicalPath.endsWith(".jar")
                && !path.canonicalPath.endsWith(".pdf")
                && !path.canonicalPath.endsWith(".zip")
                && !path.canonicalPath.endsWith("._trace")
                && !path.canonicalPath.endsWith("jOOQ-tools")
                && !path.canonicalPath.endsWith("jOOQ-website")
                && !path.canonicalPath.contains("\\access")
                && !path.canonicalPath.contains("\\ase")
                && !path.canonicalPath.contains("\\db2")
                && !path.canonicalPath.contains("\\ingres")
                && !path.canonicalPath.contains("\\oracle")
                && !path.canonicalPath.contains("\\sqlserver")
                && !path.canonicalPath.contains("\\sybase")
                && !path.canonicalPath.contains("\\target")
            ];

            for (file : files) {
                transform(inRoot, outRoot, file);
            }            
        }
        else {
            ex.submit[ | 
                var content = read(in);
    
                for (pair : patterns) {
                    content = pair.left.matcher(content).replaceAll(pair.right);
                }
                
                write(out, content);
            ];
        }
    }
    
    val patterns = new ArrayList<ImmutablePair<Pattern, String>>();
    
    new() {
        
        // Remove sections of commercial code
        patterns.add(new ImmutablePair(compile('''(?s:[ \t]+«quote("/* [com] */")»[ \t]*[\r\n]{0,2}.*?«quote("/* [/com] */")»[ \t]*[\r\n]{0,2})'''), ""));
        patterns.add(new ImmutablePair(compile('''(?s:«quote("/* [com] */")».*?«quote("/* [/com] */")»)'''), ""));
        
        patterns.add(new ImmutablePair(compile('''(?s:[ \t]+«quote("<!-- [com] -->")»[ \t]*[\r\n]{0,2}.*?«quote("<!-- [/com] -->")»[ \t]*[\r\n]{0,2})'''), ""));
        patterns.add(new ImmutablePair(compile('''(?s:«quote("<!-- [com] -->")».*?«quote("<!-- [/com] -->")»)'''), ""));
        
        for (d : SQLDialect::values.filter[d | d.commercial]) {
            
            // Remove commercial dialects from @Support annotations
            patterns.add(new ImmutablePair(compile('''(?s:(\@Support\([^\)]*?),\s*\b«d.name»\b([^\)]*?\)))'''), "$1$2"));
            patterns.add(new ImmutablePair(compile('''(?s:(\@Support\([^\)]*?)\b«d.name»\b,\s*([^\)]*?\)))'''), "$1$2"));
            patterns.add(new ImmutablePair(compile('''(?s:(\@Support\([^\)]*?)\s*\b«d.name»\b\s*([^\)]*?\)))'''), "$1$2"));
            
            // Remove commercial dialects from Arrays.asList() expressions
            patterns.add(new ImmutablePair(compile('''(asList\([^\)]*?),\s*\b«d.name»\b([^\)]*?\))'''), "$1$2"));
            patterns.add(new ImmutablePair(compile('''(asList\([^\)]*?)\b«d.name»\b,\s*([^\)]*?\))'''), "$1$2"));
            patterns.add(new ImmutablePair(compile('''(asList\([^\)]*?)\s*\b«d.name»\b\s*([^\)]*?\))'''), "$1$2"));
            
            // Remove commercial dialects from imports
            patterns.add(new ImmutablePair(compile('''import (static )?org\.jooq\.SQLDialect\.«d.name»;[\r\n]{0,2}'''), ""));
            patterns.add(new ImmutablePair(compile('''import (static )?org\.jooq\.util\.«d.name.toLowerCase»\..*?;[\r\n]{0,2}'''), ""));
        }
    }
}